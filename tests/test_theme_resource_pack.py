import pathlib,unittest
R=pathlib.Path(__file__).resolve().parents[1]
class ResourcePack(unittest.TestCase):
 def test_metadata_ignored(self):
  s=(R/'Sources/DYLThemeManager.m').read_text()
  self.assertIn('DYLResourceImages(unzipRoot)',s)
  self.assertIn('isEqualToString:@"__MACOSX"',s)
  self.assertIn('NSFileTypeRegular',s)
 def test_scale_and_invalid_manifest(self):
  s=(R/'Sources/DYLThemeManager.m').read_text()
  self.assertIn('UIScreen.mainScreen.scale',s)
  self.assertIn('BOOL explicitScale',s)
  self.assertIn('@"主题配置文件无效"',s)
  self.assertIn('stringByAppendingString:NSUUID.UUID.UUIDString',s)
if __name__=='__main__':unittest.main()
