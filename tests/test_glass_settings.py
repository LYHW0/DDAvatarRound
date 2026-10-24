"""Static wiring checks; these do not replace UIKit device tests."""
import pathlib, unittest, re
ROOT = pathlib.Path(__file__).resolve().parents[1]
class SettingsWiring(unittest.TestCase):
    def test_glass_menu_first(self):
        s=(ROOT/'Sources/LYHWPluginUI.m').read_text()
        self.assertRegex(s, r'NSArray \*pages = @\[\s*P\(@"悬浮底栏"')
    def test_all_switches_declared_and_implemented(self):
        h=(ROOT/'Sources/LYHWConfig.h').read_text()
        m=(ROOT/'Sources/LYHWConfig.m').read_text()
        ui=(ROOT/'Sources/LYHWPluginUI.m').read_text()
        keys=['glassTabBarEnabled','glassDisableMask','glassStereo','glassGlow','glassLongPress','glassSlidingMask','glassHideRedDot','glassHideBadge','glassHideText']
        for k in keys:
            self.assertIn('BOOL '+k+';',h)
            self.assertIn('LYHW_BOOL('+k+',',m)
            self.assertIn('@"'+k+'"',ui)
    def test_settings_geometry_independent(self):
        s=(ROOT/'Sources/LYHWCellCards.x').read_text()
        self.assertIn('actualSettingsPage = settingPage && !profileLike',s)
        self.assertIn('c.settingPageCornerRadius',s)
        self.assertIn('c.settingPageCornerMargin',s)
    def test_previous_mainframe_fixes_preserved(self):
        cards=(ROOT/'Sources/LYHWCellCards.x').read_text()
        corners=(ROOT/'Sources/LYHWCorner.x').read_text()
        self.assertNotIn('NSMutableArray *cands',cards)
        self.assertNotIn('%hook MainFrameTableView',corners)
if __name__=='__main__': unittest.main()
