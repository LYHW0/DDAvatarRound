import pathlib, unittest
R=pathlib.Path(__file__).resolve().parents[1]/'Sources'
class Profile54(unittest.TestCase):
 def test_previous_profile_implementation_restored(self):
  s=(R/'LYHWCellCards.x').read_text()
  self.assertIn('static void LYHWStyleInfoHeader',s)
  self.assertNotIn('kind == 0 || kind == 7',s)
  self.assertIn('LYHWStyleInfoHeader((UITableView *)self)',s)
 def test_profile_margin_menu_restored(self):
  s=(R/'LYHWPluginUI.m').read_text()
  self.assertIn('@"profilePageCornerMargin"',s)
  profile=(R/'LYHWProfileCard.x').read_text()
  self.assertIn('if (!cfg.profileCornerEnabled || YES) return;',profile)
 def test_plain_top_keeps_buttons(self):
  s=(R/'LYHWNavigationBackground.x').read_text()
  self.assertIn('hidesSharedBackground',s)
  self.assertIn('hidesBackground',s)
  for bad in ['removeFromSuperview','hidden = YES','target =','setNeedsLayout','layoutIfNeeded']:
   self.assertNotIn(bad,s)
if __name__=='__main__':unittest.main()
