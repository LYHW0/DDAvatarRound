from pathlib import Path
import unittest
R=Path(__file__).resolve().parents[1]
class NoTheme61(unittest.TestCase):
 def test_modules_removed(self):
  for name in ['DYLAppearance.m','DYLFontManager.m','DYLThemeManager.m','DYLSettingsController.m','LYHWThemeBubbleLayout.x']:
   self.assertFalse((R/'Sources'/name).exists())
 def test_no_startup_or_menu(self):
  self.assertNotIn('DYLAppearanceStart',(R/'Tweak.x').read_text())
  s=(R/'Sources/LYHWPluginUI.m').read_text()
  self.assertNotIn('字体与主题 DIY',s)
  self.assertNotIn('DYLSettingsController',s)
 def test_other_features_preserved(self):
  self.assertTrue((R/'Sources/LYHWChatTitleContrast.x').exists())
  self.assertTrue((R/'Sources/LYHWGlassTabBar.x').exists())
  self.assertIn('LYHWPointOutsideOwnedCard',(R/'Sources/LYHWCellCards.x').read_text())
if __name__=='__main__': unittest.main()
