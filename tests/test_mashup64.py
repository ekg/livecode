"""Compile/render the saved mashup without booting Tidal's scheduler or SC."""
import ast
from pathlib import Path
import re
import shutil
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1]


class Mashup64Tests(unittest.TestCase):
    @unittest.skipUnless(shutil.which('ghci'), 'ghci is required')
    def test_saved_streams_compile_without_arrange_and_render(self):
        source = (ROOT / '64.tidal').read_text()
        self.assertNotRegex(source, r'\barrange\b|fast dur pat')
        commands = [':set -XOverloadedStrings -Wno-type-defaults',
                    'import Sound.Tidal.Boot',
                    'default (Rational, Integer, Double, Pattern String)']
        commands += [line for line in (ROOT / 'BootTidal.hs').read_text().splitlines()
                     if line.startswith('let ')]
        names = []
        for line in source.splitlines():
            if line.startswith('let '):
                commands.append(line)
            match = re.fullmatch(r'd(\d+) \$ (.*)', line)
            if match:
                name = 'check' + match[1]
                names.append(name)
                commands.append('let ' + name + ' = ' + match[2])
        self.assertEqual(len(names), 12)
        commands += ['print (map (\\p -> length (queryArc p (Arc 0 64))) ['
                     + ', '.join(names) + '])',
                     'print (map (\\t -> length (queryArc check7 (Arc t (t+8)))) [0,8,16,24,32,40,48,56])',
                     ':quit']
        result = subprocess.run(['ghci', '-ignore-dot-ghci', '-v0'],
                                input='\n'.join(commands) + '\n', text=True,
                                capture_output=True, timeout=30, cwd=ROOT)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertNotRegex(result.stderr + result.stdout, r'error:|Exception')
        rows = [ast.literal_eval(line) for line in result.stdout.splitlines()
                if line.startswith('[')]
        self.assertEqual(len(rows), 2, result.stdout)
        self.assertTrue(all(n > 0 for n in rows[0][:9]), rows[0])
        self.assertEqual(rows[0][9:], [0, 0, 0])
        self.assertTrue(all(n > 0 for n in rows[1]), rows[1])


if __name__ == '__main__':
    unittest.main()
