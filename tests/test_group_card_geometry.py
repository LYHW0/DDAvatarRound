import unittest
# 与 ObjC helper 相同的 row 遍历和 gap 判定，不依赖 UIKit。
def adjacent(rows, i, before):
    start=i-1 if before else i+1
    for j in range(start,-1,-1) if before else range(start,len(rows)):
        if rows[j][1]<=1: continue
        gap=rows[i][0]-(rows[j][0]+rows[j][1]) if before else rows[j][0]-(rows[i][0]+rows[i][1])
        return j if -1<=gap<=1.5 else None
    return None
def block(rows,i):
    ids={i}
    for direction in (True,False):
        cur=i
        for _ in range(512):
            nxt=adjacent(rows,cur,direction)
            if nxt is None: break
            ids.add(nxt);cur=nxt
    return min(rows[j][0] for j in ids),max(rows[j][0]+rows[j][1] for j in ids)
class Cases(unittest.TestCase):
    def test_member_grid_with_more_row(self):
        rows=[(0,88),(88,88),(176,88),(264,88),(352,14),(374,56)]
        for i in range(5): self.assertEqual(block(rows,i),(0,366))
        self.assertEqual(block(rows,5),(374,430))
    def test_settings_four_row_section(self):
        rows=[(0,56),(56,56),(112,56),(168,56),(232,56)]
        for i in range(4): self.assertEqual(block(rows,i),(0,224))
        self.assertEqual(block(rows,4),(232,288))
    def test_cross_section_zero_gap(self):
        self.assertEqual(block([(0,50),(50,50)],1),(0,100))
    def test_zero_height_placeholder(self):
        self.assertEqual(block([(0,50),(50,0),(50,50)],0),(0,100))
    def test_short_bottom_row_uses_full_height(self):
        top,bottom=block([(0,88),(88,14)],1)
        self.assertEqual((top-88,bottom-top),(-88,102))
if __name__=='__main__': unittest.main()
