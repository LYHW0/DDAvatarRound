import pathlib,unittest
R=pathlib.Path(__file__).resolve().parents[1]
class Slim53(unittest.TestCase):
 def test_bottom_only(self):
  s=(R/'Sources/LYHWGlassTabBar.x').read_text()
  for bad in ['setHidesSharedBackground','UINavigationItem','UILongPressGestureRecognizer','CAShapeLayer','glassHideText','glassGlow']:
   self.assertNotIn(bad,s)
  for key in ['glassHideRedDot','glassHideBadge']: self.assertIn(key,s)
 def test_service_single_entry(self):
  s=(R/'Sources/LYHWPluginUI.m').read_text()
  self.assertEqual(s.count('@"servicePageCornerEnabled"'),1)
  self.assertNotIn('@"glassDisableMask"',s)
 def test_details_lifecycle_and_member_exclusion(self):
  s=(R/'Sources/LYHWCellCards.x').read_text()
  self.assertIn('%hook ChatRoomInfoViewController',s)
  self.assertIn('if (!isGroup && memberCell)',s)
  self.assertIn('vc.parentViewController',s)
 def test_discover_uses_cell_coordinates(self):
  s=(R/'Sources/LYHWCellCards.x').read_text()
  self.assertIn('if (contactsCard || discoveryCard)',s)
  self.assertIn('CGFloat discoverTop',s)
if __name__=='__main__': unittest.main()
