import pathlib,unittest
R=pathlib.Path(__file__).resolve().parents[1]/'Sources'
class Visual57(unittest.TestCase):
 def test_profile_shadow_on_card(self):
  s=(R/'LYHWCellCards.x').read_text().split('static void LYHWStyleInfoHeader',1)[1].split('static void LYHWStyleMyHeader',1)[0]
  self.assertIn('LYHWSetSinkShadow(card.layer, card.bounds',s)
  self.assertIn('LYHWPaintListSurface(tv, nil)',s)
 def test_title_chat_only(self):
  s=(R/'LYHWChatTitleContrast.x').read_text()
  self.assertIn('topbarCornerEnabled',s)
  self.assertIn('MMTitleView',s)
  self.assertIn('MMMsgContentNavBar',s)
  self.assertIn('NSForegroundColorAttributeName',s)
  self.assertIn('UIUserInterfaceStyleDark',s)
if __name__=='__main__': unittest.main()
