import pathlib, unittest
R=pathlib.Path(__file__).resolve().parents[1]/'Sources'
class Profile54(unittest.TestCase):
 def test_source_profile_owns_page(self):
  s=(R/'LYHWProfileCard.x').read_text()
  self.assertNotIn('|| YES',s)
  self.assertIn('profilePageCornerEnabled',s)
  self.assertIn('LYHWApplyCorner(cell.contentView, radius, 0, nil, YES)',s)
  self.assertIn('table.visibleCells',s)
 def test_no_old_header_overlay(self):
  s=(R/'LYHWCellCards.x').read_text()
  self.assertNotIn('static void LYHWStyleInfoHeader',s)
  self.assertIn('kind == 0 || kind == 7',s)
 def test_plain_top_keeps_buttons(self):
  s=(R/'LYHWNavigationBackground.x').read_text()
  self.assertIn('hidesSharedBackground',s)
  self.assertIn('hidesBackground',s)
  for bad in ['removeFromSuperview','hidden = YES','target =','setNeedsLayout','layoutIfNeeded']:
   self.assertNotIn(bad,s)
if __name__=='__main__':unittest.main()
