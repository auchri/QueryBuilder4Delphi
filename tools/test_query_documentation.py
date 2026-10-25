"""Focused contracts for the fluent XML templates and regeneration."""
import unittest
import xml.etree.ElementTree as ET
from generated_sections import replace_section
from query_documentation import fluent_doc, xml_doc


def doc(name, signature):
    lines=fluent_doc(name,signature).splitlines()
    return ET.fromstring('<doc>'+' '.join(line.strip()[4:] for line in lines)+'</doc>')


def prose(root):
    return ' '.join(root.itertext())


class QueryDocumentationTests(unittest.TestCase):
    def test_shorthand_only_on_expanding_methods(self):
        for name in ('Select','GroupBy','OrderBy','OrderByDesc'):
            for signature in ('const Column: string','const Columns: array of string'):
                with self.subTest(name=name,signature=signature):
                    root=doc(name,signature)
                    self.assertIn('Books.{Id, Title}',prose(root))
                    self.assertIn("'Books.Id' and 'Books.Title'",prose(root))
                    self.assertIn('not SQL syntax',prose(root))
                    if name!='Select': self.assertNotIn('alias',prose(root))
        root=doc('AsCount','const Columns: array of string')
        self.assertIn('Only the DISTINCT rewrite expands',prose(root))
        self.assertIn('empty array selects COUNT(*)',prose(root))
        self.assertNotIn('Books.{',prose(root))

    def test_predicate_overloads_describe_their_operand(self):
        direct=prose(doc('Where','const Column: string; const Value: TValue'))
        explicit=prose(doc('Where','const Column, Op: string; const Value: TValue'))
        group=prose(doc('Where','const Callback: TQueryCallback'))
        subquery=prose(doc('Where','const Column, Op: string; Query: IQuery'))
        self.assertIn('Uses equality',direct)
        self.assertNotIn('Uses equality',explicit)
        self.assertIn('parenthesized',group)
        self.assertIn('scalar subquery',subquery)
        self.assertNotIn('SQL NULL',subquery)

    def test_empty_in_and_aggregate_filter(self):
        self.assertIn('false for IN',prose(doc('WhereIn','const Column: string; const Values: array of TValue')))
        self.assertIn('true for NOT IN',prose(doc('WhereNotIn','const Column: string; const Values: array of TValue')))
        root=doc('SelectCount','const Column: string; const Filter: TQueryCallback = nil')
        self.assertIn('WHERE predicates',prose(root))
        self.assertIn('when assigned',prose(root))
        self.assertNotIn('EArgumentNilException',[e.get('cref') for e in root.findall('exception')])

    def test_exception_conditions_are_consolidated_without_losing_failures(self):
        root=doc('WhereNotExists','const Callback: TQueryCallback')
        self.assertEqual(['EQueryException','EArgumentNilException'],[e.get('cref') for e in root.findall('exception')])
        text=root.find('exception[@cref="EQueryException"]').text
        self.assertIn('FROM',text)
        self.assertIn('different query or nil',text)

    def test_raw_overloads_and_operation_keywords(self):
        empty=prose(doc('UnionRaw','const Sql: string'))
        bound=prose(doc('UnionRaw','const Sql: string; const Bindings: array of TValue'))
        self.assertIn('adds no operation keyword',empty)
        self.assertIn('UNION SELECT',empty)
        self.assertIn('no bindings',empty)
        self.assertNotIn('no bindings',bound)
        self.assertIn('except TBytes',bound)
        self.assertIn('escape remains in executable SQL',bound)

    def test_xml_escaping_and_exception_deduplication(self):
        xml=xml_doc('A < B & C',exceptions=[('EQueryException','first'),('EQueryException','second'),('EQueryException','first')])
        root=ET.fromstring('<doc>'+''.join(line.strip()[4:] for line in xml.splitlines())+'</doc>')
        self.assertEqual('A < B & C',root.find('summary').text)
        self.assertEqual('first second',root.find('exception').text)
        self.assertEqual(1,len(root.findall('exception')))

    def test_doc_update_preserves_formatted_declarations_and_implementation(self):
        original=('// BEGIN GENERATED: api\n    /// <summary>Old</summary>\n'
                  '    function Select(\n      const Column: string\n    ): IQuery; overload;\n'
                  '// END GENERATED: api\nimplementation\n// BEGIN GENERATED: body\n'
                  'begin\n  Result := Self;\nend;\n// END GENERATED: body\n')
        generated=fluent_doc('Select','const Column: string')+'\n    function Select(const Column: string): IQuery; overload;'
        updated=replace_section(original,'api',generated)
        self.assertIn('function Select(\n      const Column: string\n    ): IQuery; overload;',updated)
        self.assertEqual(updated,replace_section(updated,'api',generated))
        self.assertEqual(updated,replace_section(updated,'body','begin Result:=Self; end;'))


if __name__=='__main__':
    unittest.main()
