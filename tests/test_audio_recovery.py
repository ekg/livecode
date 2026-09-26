"""Static guards for the September silent-master regression.
The runtime gate in sc/init.scd separately tests every orbit through bus 0.
Run: python3 -m unittest discover -s tests -p 'test_audio_recovery.py'
"""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]


class AudioRecoveryTests(unittest.TestCase):
    def test_master_returns_audio_after_meter_writes(self):
        source = (ROOT / 'sc/dub_master.scd').read_text()
        graph = source.split('Ndef(\\dubMaster, {', 1)[1].split('\n});', 1)[0]
        graph = re.sub(r'//[^\n]*', '', graph)
        self.assertRegex(graph.strip(), r'Splay\.ar\(sig\.asArray,.*\);$')
        self.assertLess(graph.rfind('Out.kr'), graph.rfind('Splay.ar'))

    def test_boot_measures_hardware_not_just_internal_meter(self):
        source = (ROOT / 'sc/init.scd').read_text()
        self.assertIn('synthH = Synth(\\bootPeak, [\\in, 0,', source)
        self.assertIn('levelH = readBus.(ctlH)', source)
        self.assertIn('levelH < 0.001', source)
        self.assertNotIn('~meterBus.getSynchronous(1)', source)


if __name__ == '__main__':
    unittest.main()
