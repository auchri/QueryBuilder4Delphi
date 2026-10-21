"""Regression tests for generators that update regular Pascal units."""

from pathlib import Path
from tempfile import TemporaryDirectory
import unittest

from generated_sections import pascal_tokens, replace_section, update_files


class GeneratedSectionTests(unittest.TestCase):
    def test_formatted_files_are_preserved_by_check_and_generation(self):
        with TemporaryDirectory() as directory:
            path = Path(directory) / 'Query.pas'
            formatted = b"begin\r\n  Value := 'a b';\r\nend;\r\n"
            path.write_bytes(formatted)
            expected = {path: "begin Value:='a b'; end;\n"}
            timestamp = path.stat().st_mtime_ns
            update_files(expected, check=True)
            update_files(expected)
            self.assertEqual(formatted, path.read_bytes())
            self.assertEqual(timestamp, path.stat().st_mtime_ns)

    def test_layout_comparison_preserves_literals_comments_and_token_boundaries(self):
        for first, second in [("'a b'", "'ab'"), ("'a'' b'", "'a''b'"),
                              ('// a b\n', '// ab\n'), ('{a b}', '{ab}'),
                              ('(* a b *)', '(* ab *)'), ('{$IFDEF A}', '{$IFDEF B}'),
                              ('Some Name', 'SomeName'), (': =', ':='),
                              ('1 . 5', '1.5'), ('Value := 1', 'Value := 2')]:
            with self.subTest(first=first, second=second):
                self.assertNotEqual(pascal_tokens(first), pascal_tokens(second))

    def test_preserves_handwritten_code_and_is_idempotent(self):
        source = ('procedure Manual;\n// BEGIN GENERATED: methods\nold\n'
                  '// END GENERATED: methods\nprocedure AlsoManual;\n')
        expected = source.replace('\nold\n', '\nnew\n')
        actual = replace_section(source, 'methods', 'new\n')
        self.assertEqual(expected, actual)
        self.assertEqual(actual, replace_section(actual, 'methods', 'new\n'))

    def test_rejects_missing_duplicated_and_reversed_markers(self):
        for source in ['', '// BEGIN GENERATED: methods\n',
                       '// END GENERATED: methods\n// BEGIN GENERATED: methods\n',
                       '// BEGIN GENERATED: methods\n// BEGIN GENERATED: methods\n'
                       '// END GENERATED: methods\n']:
            with self.subTest(source=source), self.assertRaises(ValueError):
                replace_section(source, 'methods', 'new')

    def test_indented_markers_preserve_surrounding_class(self):
        source = ('class\n    // BEGIN GENERATED: declarations\nold\n'
                  '    // END GENERATED: declarations\nend;\n')
        self.assertEqual(source.replace('\nold\n', '\n    function New: Integer;\n'),
                         replace_section(source, 'declarations',
                                         '    function New: Integer;', '    '))

    def test_check_reports_stale_files_without_writing(self):
        with TemporaryDirectory() as directory:
            path = Path(directory) / 'Query.pas'
            path.write_bytes(b'old\r\n')
            with self.assertRaises(SystemExit):
                update_files({path: 'new\n'}, check=True)
            self.assertEqual(b'old\r\n', path.read_bytes())

    def test_writer_preserves_bom_crlf_and_unchanged_files(self):
        with TemporaryDirectory() as directory:
            path = Path(directory) / 'Query.pas'
            path.write_bytes(b'\xef\xbb\xbfold\r\n')
            update_files({path: 'new\n'})
            self.assertEqual(b'\xef\xbb\xbfnew\r\n', path.read_bytes())
            timestamp = path.stat().st_mtime_ns
            update_files({path: 'new\n'}, check=True)
            update_files({path: 'new\n'})
            self.assertEqual(timestamp, path.stat().st_mtime_ns)

    def test_check_does_not_create_missing_files(self):
        with TemporaryDirectory() as directory:
            path = Path(directory) / 'Missing.pas'
            with self.assertRaises(SystemExit):
                update_files({path: 'unit Missing;\n'}, check=True)
            self.assertFalse(path.exists())


if __name__ == '__main__':
    unittest.main()
