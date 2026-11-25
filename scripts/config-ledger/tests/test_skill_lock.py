import importlib.util
from pathlib import Path
import tempfile
import unittest

spec = importlib.util.spec_from_file_location('drift', Path(__file__).parents[1] / 'drift.py')
drift = importlib.util.module_from_spec(spec)
spec.loader.exec_module(drift)


class SkillLockTests(unittest.TestCase):
    def test_renamed_skill_and_invalid_installations(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            folder = root / 'code-review-mp'
            folder.mkdir()
            skill = folder / 'SKILL.md'
            entry = {'skillName': 'code-review'}
            for content, expected in [
                ('---\nname: code-review-mp\n---\n', []),
                ('---\nname: code-review\n---\n', ['skill lock: code-review-mp has installed name code-review']),
                ('---\ndescription: missing name\n---\n', ['skill lock: code-review-mp has no valid installed name']),
            ]:
                with self.subTest(content=content):
                    skill.write_text(content)
                    differences = []
                    drift.check_skill_lock('code-review-mp', entry, root, differences)
                    self.assertEqual(differences, expected)
            skill.unlink()
            differences = []
            drift.check_skill_lock('code-review-mp', entry, root, differences)
            self.assertEqual(differences, [f'skill lock: missing {skill}'])
            folder.rmdir()
            differences = []
            drift.check_skill_lock('code-review-mp', entry, root, differences)
            self.assertEqual(differences, ['skill lock: missing installed folder code-review-mp (skillName code-review)'])

    def test_unlisted_rename_is_reported(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            folder = root / 'foo-renamed'
            folder.mkdir()
            (folder / 'SKILL.md').write_text('---\nname: foo-renamed\n---\n')
            differences = []
            drift.check_skill_lock('foo-renamed', {'skillName': 'foo'}, root, differences)
            self.assertEqual(differences, [
                'skill lock: foo-renamed installed under folder foo-renamed, skillName is foo'
            ])


if __name__ == '__main__':
    unittest.main()
