// Small local CSV/XLSX reader. ZIP/XML only; no requests or third-party packages.
export async function readImport(b) {
  const error=message=>{throw {status:422,body:{code:'import.format',message,traceId:'demo-local'}};};
  let bytes;try{bytes=Uint8Array.from(atob(b.contentBase64),c=>c.charCodeAt(0));}catch{error('El archivo no se pudo leer.');}
  if(bytes.length>5*1024*1024)error('El archivo supera 5 MB.');
  let rows;
  if(/\.csv$/i.test(b.fileName)) rows=parseCsv(new TextDecoder().decode(bytes).replace(/^\ufeff/,''));
  else if(/\.xlsx$/i.test(b.fileName)) {
    const view=new DataView(bytes.buffer), files={};
    let end=bytes.length-22;while(end>=0&&view.getUint32(end,true)!==0x06054b50)end--;
    if(end<0)error('XLSX invalido.');
    let at=view.getUint32(end+16,true),total=0;
    for(let n=0;n<view.getUint16(end+10,true);n++){
      if(view.getUint32(at,true)!==0x02014b50)error('XLSX invalido.');
      const method=view.getUint16(at+10,true), compressed=view.getUint32(at+20,true), size=view.getUint32(at+24,true),length=view.getUint16(at+28,true),extra=view.getUint16(at+30,true),comment=view.getUint16(at+32,true),offset=view.getUint32(at+42,true);
      total+=size;if(total>20*1024*1024)error('XLSX demasiado grande.');
      const name=new TextDecoder().decode(bytes.slice(at+46,at+46+length));
      if(/^xl\/(sharedStrings\.xml|worksheets\/sheet1\.xml)$/.test(name)){
        const start=offset+30+view.getUint16(offset+26,true)+view.getUint16(offset+28,true), data=bytes.slice(start,start+compressed);
        if(method===0)files[name]=new TextDecoder().decode(data);
        else if(method===8)files[name]=await new Response(new Blob([data]).stream().pipeThrough(new DecompressionStream('deflate-raw'))).text();
        else error('Compresion XLSX no admitida.');
      }
      at+=46+length+extra+comment;
    }
    const decode=t=>t.replace(/&(?:amp|lt|gt|quot|apos);/g,s=>({'&amp;':'&','&lt;':'<','&gt;':'>','&quot;':'"','&apos;':"'"})[s]);
    const texts=xml=>[...xml.matchAll(/<t(?:\s[^>]*)?>([\s\S]*?)<\/t>/g)].map(m=>decode(m[1])).join('');
    const shared=[...(files['xl/sharedStrings.xml']??'').matchAll(/<si(?:\s[^>]*)?>([\s\S]*?)<\/si>/g)].map(m=>texts(m[1]));
    const sheet=files['xl/worksheets/sheet1.xml'];if(!sheet)error('Falta la primera hoja XLSX.');
    rows=[...sheet.matchAll(/<row(?:\s[^>]*)?>([\s\S]*?)<\/row>/g)].map(row=>{
      const cells=[];for(const m of row[1].matchAll(/<c\b([^>]*?)(?:\/>|>([\s\S]*?)<\/c>)/g)){
        const ref=m[1].match(/\br="([A-Z]+)\d+"/)?.[1]??'A';let col=0;for(const c of ref)col=col*26+c.charCodeAt(0)-64;
        const v=m[2]?.match(/<v>([\s\S]*?)<\/v>/)?.[1]??'';cells[col-1]=/\bt="s"/.test(m[1])?(shared[Number(v)]??''):/\bt="inlineStr"/.test(m[1])?texts(m[2]??''):decode(v);
      }return Array.from({length:cells.length},(_,i)=>cells[i]??'');
    });
  }else error('Use CSV o XLSX.');
  if(rows.length>5001)error('El archivo supera 5000 filas.');
  return {fileName:b.fileName,headers:rows.shift()??[],rows};
}
function parseCsv(text){
  const rows=[];let row=[],cell='',quoted=false;
  for(let i=0;i<text.length;i++){const c=text[i];if(c==='"'){if(quoted&&text[i+1]==='"'){cell+='"';i++;}else quoted=!quoted;}else if(c===','&&!quoted){row.push(cell);cell='';}else if((c==='\n'||c==='\r')&&!quoted){if(c==='\r'&&text[i+1]==='\n')i++;row.push(cell);if(row.some(Boolean))rows.push(row);row=[];cell='';}else cell+=c;}
  row.push(cell);if(row.some(Boolean))rows.push(row);return rows;
}
