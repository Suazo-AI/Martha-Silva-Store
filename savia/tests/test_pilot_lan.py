"""pilot.py up --lan guard: only a private LAN IPv4 is accepted. No process, network or database is touched."""
import os
import sys
import unittest
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools'))
import pilot


class PilotLanTests(unittest.TestCase):
    def test_private_ranges_are_accepted(self):
        for ip in ('10.0.0.5', '172.16.4.20', '172.31.255.1', '192.168.1.34'):
            self.assertEqual(pilot.private_lan_ip(ip), ip)

    def test_public_loopback_and_other_addresses_are_refused(self):
        for ip in ('8.8.8.8', '127.0.0.1', '0.0.0.0', '172.32.0.1', '100.64.0.1', '169.254.1.1', '::1', 'fd00::1', 'casa', ''):
            with self.subTest(ip=ip), self.assertRaises(SystemExit):
                pilot.private_lan_ip(ip)

    def test_default_stays_loopback_and_lan_adds_one_private_url(self):
        self.assertEqual(pilot.listen_urls(), 'http://127.0.0.1:5080')
        self.assertEqual(pilot.listen_urls('192.168.1.34'), 'http://127.0.0.1:5080;http://192.168.1.34:5080')
        with self.assertRaises(SystemExit):
            pilot.listen_urls('203.0.113.7')

    def test_chosen_ip_must_be_private_too(self):
        with patch.dict(os.environ, {'SAVIA_PILOT_LAN_IP': '203.0.113.7'}):
            with self.assertRaises(SystemExit):
                pilot.detect_lan_ip()
        with patch.dict(os.environ, {'SAVIA_PILOT_LAN_IP': '192.168.0.10'}):
            self.assertEqual(pilot.detect_lan_ip(), '192.168.0.10')


if __name__ == '__main__':
    unittest.main()
