import pathlib,unittest
S=(pathlib.Path(__file__).resolve().parents[1]/'Sources/LYHWCellCards.x').read_text()
class CardHit(unittest.TestCase):
 def test_owned_only(self):
  h=S.split('static BOOL LYHWPointOutsideOwnedCard',1)[1].split('%hook UITableView',1)[0]
  self.assertIn('card.tag != 0x574352',h)
  self.assertIn('LYHWCellIsSwiped(cell)',h)
  self.assertIn('[path containsPoint:local]',h)
 def test_keep_scrolling(self):
  self.assertIn('if (LYHWPointOutsideOwnedCard((UITableView *)self,ip,point)) return (UIView *)self;',S)
  self.assertNotIn('scrollEnabled = NO',S)
 def test_margin_model(self):
  rect=(10,0,373,56)
  for x,y,inside in [(5,28,False),(390,28,False),(50,28,True),(50,60,False)]:
   self.assertEqual(rect[0]<=x<=rect[0]+rect[2] and rect[1]<=y<=rect[1]+rect[3],inside)
if __name__=='__main__':unittest.main()
