local core = require('gitgraph.core')

---@class GG.Test
---@field name string
---@field commits string[]
---@field expect string[]
---@field ignore? boolean

local M = {}

---@type GG.Test[]
M.scenarios = {
  {
    name = 'foo',
    commits = {
      'G D',
      'F C',
      'E C',
      'D AB',
      'C A',
      'B A',
      'A',
    },
    expect = {
      'G           G           G 1  :  _ G D',
      'd           │',
      'D F         │ F         F 2  :  _ F C',
      'D c         │ │',
      'D C E       │ │ E       E 3  :  _ E C',
      'D C c       │ ├─╯',
      'D C         D │         D 4  :  G D AB',
      'a C   b     ├─│───╮',
      'A C   B     │ C   │     C 5  :  FE C A',
      'A a   B     │ │   │',
      'A A   B     │ │   B     B 6  :  D B A',
      'A A   a     ├─┴───╯',
      'A           A           A 7  :  DCB A',
    },
  },
  {
    name = 'bar',
    commits = {
      'F C',
      'E B',
      'D A',
      'C BA',
      'B A',
      'A',
    },
    expect = {
      'F         F         F 1  :  _ F C',
      'c         │',
      'C E       │ E       E 2  :  _ E B',
      'C b       │ │',
      'C B D     │ │ D     D 3  :  _ D A',
      'C B a     │ │ │',
      'C B A     C │ │     C 4  :  F C BA',
      'b B a     ├─┴─┤',
      'B   A     B   │     B 5  :  EC B A',
      'a   A     ├───╯',
      'A         A         A 6  :  DCB A',
    },
  },
  {
    name = 'bi-crossing 1',
    commits = {
      'J G',
      'I F',
      'H F',
      'G EB',
      'F D',
      'E A',
      'D A',
      'C A',
      'B A',
      'A',
    },
    expect = {
      'J           J           J 1  :  _ J G',
      'g           │',
      'G I         │ I         I 2  :  _ I F',
      'G f         │ │',
      'G F H       │ │ H       H 3  :  _ H F',
      'G F f       │ ├─╯',
      'G F         G │         G 4  :  J G EB',
      'e F   b     ├─│───╮',
      'E F   B     │ F   │     F 5  :  IH F D',
      'E d   B     │ │   │',
      'E D   B     E │   │     E 6  :  G E A',
      'a D   B     │ │   │',
      'A D   B     │ D   │     D 7  :  F D A',
      'A a   B     │ │   │',
      'A A C B     │ │ C │     C 8  :  _ C A',
      'A A a B     │ │ │ │',
      'A A A B     │ │ │ B     B 9  :  G B A',
      'A A A a     ├─┴─┴─╯',
      'A           A           A 10  :  EDCB A',
    },
  },
  {
    name = 'bi-crossing 2',
    commits = {
      'G C',
      'F D',
      'E C',
      'D CB',
      'C A',
      'B A ',
      'A',
    },
    expect = {
      'G         G         G 1  :  _ G C',
      'c         │',
      'C F       │ F       F 2  :  _ F D',
      'C d       │ │',
      'C D E     │ │ E     E 3  :  _ E C',
      'C D c     ├─│─╯',
      'C D       │ D       D 4  :  F D CB',
      'c b       ├─┤',
      'C B       C │       C 5  :  GED C A',
      'a B       │ │',
      'A B       │ B       B 6  :  D B A',
      'A a       ├─╯',
      'A         A         A 7  :  CB A',
    },
  },
  {
    name = 'branch out',
    commits = {
      'E AB',
      'D B',
      'C B',
      'B A',
      'A',
    },
    expect = {
      'E           E           E 1  :  _ E AB',
      'a b         ├─╮',
      'A B D       │ │ D       D 2  :  _ D B',
      'A B b       │ │ │',
      'A B B C     │ │ │ C     C 3  :  _ C B',
      'A B B b     │ ├─┴─╯',
      'A B         │ B         B 4  :  EDC B A',
      'A a         ├─╯',
      'A           A           A 5  :  EB A',
    },
  },
  {
    name = 'branch in',
    commits = {
      'F B',
      'E BDC',
      'D A',
      'C A',
      'B A',
      'A',
    },
    expect = {
      'F           F           F 1  :  _ F B',
      'b           │',
      'B E         │ E         E 2  :  _ E BDC',
      'B b d c     │ ├─┬─╮',
      'B B D C     │ │ D │     D 3  :  E D A',
      'B B a C     │ │ │ │',
      'B B A C     │ │ │ C     C 4  :  E C A',
      'B B A a     ├─╯ │ │',
      'B   A A     B   │ │     B 5  :  FE B A',
      'a   A A     ├───┴─╯',
      'A           A           A 6  :  DCB A',
    },
  },
  {
    name = 'ultra branch in',
    commits = {
      'H E',
      'G E',
      'F EDC',
      'E B',
      'D A',
      'C A',
      'B A',
      'A',
    },
    expect = {
      'H           H           H 1  :  _ H E',
      'e           │',
      'E G         │ G         G 2  :  _ G E',
      'E e         ├─╯',
      'E   F       │   F       F 3  :  _ F EDC',
      'e   d c     ├───┼─╮',
      'E   D C     E   │ │     E 4  :  HGF E B',
      'b   D C     │   │ │',
      'B   D C     │   D │     D 5  :  F D A',
      'B   a C     │   │ │',
      'B   A C     │   │ C     C 6  :  F C A',
      'B   A a     │   │ │',
      'B   A A     B   │ │     B 7  :  E B A',
      'a   A A     ├───┴─╯',
      'A           A           A 8  :  DCB A',
    },
  },
  {
    name = 'alphred',
    commits = {
      'G DCBFE',
      'F E',
      'E D',
      'D CA',
      'C A',
      'B A',
      'A',
    },
    expect = {
      'G             G             G 1  :  _ G DCBFE',
      'd c b f e     ├─┬─┬─┬─╮',
      'D C B F E     │ │ │ F │     F 2  :  G F E',
      'D C B e E     │ │ │ ├─╯',
      'D C B E       │ │ │ E       E 3  :  GF E D',
      'D C B d       ├─│─│─╯',
      'D C B         D │ │         D 4  :  GE D CA',
      'a c B         ├─┤ │',
      'A C B         │ C │         C 5  :  GD C A',
      'A a B         │ │ │',
      'A A B         │ │ B         B 6  :  G B A',
      'A A a         ├─┴─╯',
      'A             A             A 7  :  DCB A',
    },
  },
  {
    name = 'gustav',
    commits = {
      'G ABFCDE',
      'F DCEB',
      'E ACB',
      'D A',
      'C B',
      'B A',
      'A',
    },
    expect = {
      'G                   G                   G 1  :  _ G ABFCDE',
      'a b f c d e         ├─┬─┬─┬─┬─╮',
      'A B F C D E         │ │ F │ │ │         F 2  :  G F DCEB',
      'A B b c d e         │ │ ├─┼─┼─┤',
      'A B B C D E         │ │ │ │ │ E         E 3  :  GF E ACB',
      'A B B C D a c b     │ │ │ │ │ ├─┬─╮',
      'A B B C D A C B     │ │ │ │ D │ │ │     D 4  :  GF D A',
      'A B B C a A C B     │ │ │ ├─│─│─╯ │',
      'A B B C A A   B     │ │ │ C │ │   │     C 5  :  GFE C B',
      'A B B b A A   B     │ ├─┴─┴─│─│───╯',
      'A B     A A         │ B     │ │         B 6  :  GFEC B A',
      'A a     A A         ├─┴─────┴─╯',
      'A                   A                   A 7  :  GEDB A',
    },
  },
  {
    name = 'frank',
    commits = {
      'G EAFDC',
      'F DEA',
      'E C',
      'D CA',
      'C B',
      'B A',
      'A',
    },
    expect = {
      'G             G             G 1  :  _ G EAFDC',
      'e a f d c     ├─┬─┬─┬─╮',
      'E A F D C     │ │ F │ │     F 2  :  G F DEA',
      'e A a d C     ├─│─┼─┤ │',
      'E A A D C     E │ │ │ │     E 3  :  GF E C',
      'c A A D C     ├─│─│─│─╯',
      'C A A D       │ │ │ D       D 4  :  GF D CA',
      'c A A a       ├─│─│─┤',
      'C A A A       C │ │ │       C 5  :  GED C B',
      'b A A A       │ │ │ │',
      'B A A A       B │ │ │       B 6  :  C B A',
      'a A A A       ├─┴─┴─╯',
      'A             A             A 7  :  GFDB A',
    },
  },
  -- {
  --   name = 'short-frank',
  --   commits = {
  --     'G EAFDC',
  --     'F DEA',
  --     'E C',
  --     'D CA',
  --   },
  --   expect = {
  --     'G ',
  --     'e a f d c ',
  --     'E A F D C ',
  --     'e A a d C ',
  --     'E A A D C ',
  --     'c A A D C ',
  --     'C A A D   ',
  --   },
  -- },
  {
    name = 'julia',
    commits = {
      'G BFDEAC',
      'F ECBA',
      'E ACB',
      'D CA',
      'C B',
      'B A',
      'A',
    },
    expect = {
      'G                 G                 G 1  :  _ G BFDEAC',
      'b f d e a c       ├─┬─┬─┬─┬─╮',
      'B F D E A C       │ F │ │ │ │       F 2  :  G F ECBA',
      'B b D e a c       │ ├─│─┼─┼─┤',
      'B B D E A C       │ │ │ E │ │       E 3  :  GF E ACB',
      'B B D a A c b     │ │ │ ├─│─┼─╮',
      'B B D A A C B     │ │ D │ │ │ │     D 4  :  G D CA',
      'B B c a A C B     │ │ ├─┼─│─╯ │',
      'B B C A A   B     │ │ C │ │   │     C 5  :  GFED C B',
      'B B b A A   B     ├─┴─┴─│─│───╯',
      'B     A A         B     │ │         B 6  :  GFEC B A',
      'a     A A         ├─────┴─╯',
      'A                 A                 A 7  :  GFEDB A',
    },
  },
  {
    name = 'letieu',
    commits = {
      'H CG',
      'G C',
      'F BE',
      'E BD',
      'D BA',
      'C B',
      'B A',
      'A',
    },
    expect = {
      'H               H               H 1  :  _ H CG',
      'c g             ├─╮',
      'C G             │ G             G 2  :  H G C',
      'C c             │ │',
      'C C F           │ │ F           F 3  :  _ F BE',
      'C C b e         │ │ ├─╮',
      'C C B E         │ │ │ E         E 4  :  F E BD',
      'C C B b d       │ │ │ ├─╮',
      'C C B B D       │ │ │ │ D       D 5  :  E D BA',
      'C C B B b a     ├─╯ │ │ ├─╮',
      'C   B B B A     C   │ │ │ │     C 6  :  HG C B',
      'b   B B B A     ├───┴─┴─╯ │',
      'B         A     B         │     B 7  :  FEDC B A',
      'a         A     ├─────────╯',
      'A               A               A 8  :  DB A',
    },
  },
  {
    name = 'different family',
    commits = {
      'H F',
      'G D',
      'F E',
      'E B',
      'D C',
      'C',
      'B A',
      'A',
    },
    expect = {
      'H       H       H 1  :  _ H F',
      'f       │',
      'F G     │ G     G 2  :  _ G D',
      'F d     │ │',
      'F D     F │     F 3  :  H F E',
      'e D     │ │',
      'E D     E │     E 4  :  F E B',
      'b D     │ │',
      'B D     │ D     D 5  :  G D C',
      'B c     │ │',
      'B C     │ C     C 6  :  D C',
      'B       │',
      'B       B       B 7  :  E B A',
      'a       │',
      'A       A       A 8  :  B A',
    },
  },
  {
    name = 'strange 1',
    commits = {
      'G ADBEF',
      'F CADEB',
      'E DA',
      'D BC',
      'C BA',
      'B A',
      'A ',
    },
    expect = {
      'G                   G                   G 1  :  _ G ADBEF',
      'a d b e f           ├─┬─┬─┬─╮',
      'A D B E F           │ │ │ │ F           F 2  :  G F CADEB',
      'A d B e c a   b     │ ├─│─┼─┼─┬───╮',
      'A D B E C A   B     │ │ │ E │ │   │     E 3  :  GF E DA',
      'A D B d C a   B     │ ├─│─┴─│─┤   │',
      'A D B   C A   B     │ D │   │ │   │     D 4  :  GFE D BC',
      'A c b   C A   B     │ ├─┼───╯ │   │',
      'A C B     A   B     │ C │     │   │     C 5  :  FD C BA',
      'A b B     a   B     │ ├─┴─────┼───╯',
      'A B       A         │ B       │         B 6  :  GFDC B A',
      'A a       A         ├─┴───────╯',
      'A                   A                   A 7  :  GFECB A',
    },
  },

  {
    name = 'strange 2',
    commits = {
      'G BDECFA',
      'F BECAD',
      'E BAD',
      'D C',
      'C AB',
      'B A',
      'A ',
    },
    expect = {
      'G                   G                   G 1  :  _ G BDECFA',
      'b d e c f a         ├─┬─┬─┬─┬─╮',
      'B D E C F A         │ │ │ │ F │         F 2  :  G F BECAD',
      'B d e C b a c       │ ├─┼─│─┼─┼─╮',
      'B D E C B A C       │ │ E │ │ │ │       E 3  :  GF E BAD',
      'B D d C b a C       │ ├─┴─│─┼─┤ │',
      'B D   C B A C       │ D   │ │ │ │       D 4  :  GFE D C',
      'B c   C B A C       │ ├───┴─│─│─╯',
      'B C     B A         │ C     │ │         C 5  :  GFD C AB',
      'B b     B a         ├─┴─────╯ │',
      'B         A         B         │         B 6  :  GFEC B A',
      'a         A         ├─────────╯',
      'A                   A                   A 7  :  GFECB A',
    },
  },
}

-- 01   G          G            G           G 1  :  _ G D
-- 02   d          │            │
-- 03   D F        │ F          │ F         F 2  :  _ F C
-- 04   D c        │ │          │ │
-- 05   D C E      │ │ E        │ │ E       E 3  :  _ E C
-- 06   D C c      │ │ │        │ │ │
-- 07   D C C      D │ │        D─│─│─╮     D 4  :  G D AB
-- 08   a C C b    ├─┼─┴─╮      │ ├─╯ │
-- 09   A C   B    │ C   │      │ C   │     C 5  :  FE C A
-- 10   A a   B    │ │   │      │ │   │
-- 11   A A   B    │ │   B      │ │   B     B 6  :  D B A
-- 12   A A   a    ├─┴───╯      ├─┴───╯
-- 13   A          A            A           A 7  :  DCB A
--
--
--      F  ⓛ              F  ⓛ        F  ⓛ        F  ⓛ
--         │                 │           │           │
--         │              E  │ ⓛ      E  │ ⓛ      E  │ ⓛ
--      E  │ ⓛ               │ │         │ │         │ │
--         │ │            D  │ │ ⓛ    D  │ │ ⓛ    D  │ │ ⓛ
--         │ │               │ │ │       │ │ │       │ │ │
--      D  │ │ ⓛ          C  ⓮ │ │    C  ⓮ │ │    C  ⓮─│─⓷
--         │ │ │             ⓺─ⓥ─⓷       ⓸─│─⓷       ⓶─╯ │
--         │ │ │          B  ⓚ   │    B  ⓚ─╯ │    B  ⓚ   │
--      C  ⓮ │ │             ⓶───╯       │   │       ⓶───╯
--         ⓸─│─⓷          A  ⓮        A  ⓮───╯    A  ⓮
--         ⓶─╯ │
--      B  ⓚ   │
--         │   │
--         ⓶───╯
--      A  ⓮
--
--
--
--
--ⓚ ⓛ   ⓵
--⓮ ⓯   ⓴
--
--⓺
--
--⓶
--⓸
--⓷
--⓹
--
--ⓢ
--ⓣ
--ⓥ
--ⓤ
--
--
-- 01   J           J          J           J 1  :  _ J G
-- 02   g           │          │
-- 03   G I         │ I        │ I         I 2  :  _ I F
-- 04   G f         │ │        │ │
-- 05   G F H       │ │ H      │ │ H       H 3  :  _ H F
-- 06   G F f       │ │ │      │ │ │
-- 07   G F F       G │ │      G─│─│─╮     G 4  :  J G EB
-- 08   e F F b     ├─┼─┴─╮    │ ├─╯ │
-- 09   E F   B     │ F   │    │ F   │     F 5  :  IH F D
-- 10   E d   B     │ │   │    │ │   │
-- 11   E D   B     E │   │    E │   │     E 6  :  G E A
-- 12   a D   B     │ │   │    │ │   │
-- 13   A D   B     │ D   │    │ D   │     D 7  :  F D A
-- 14   A a   B     │ │   │    │ │   │
-- 15   A A C B     │ │ C │    │ │ C │     C 8  :  _ C A
-- 16   A A a B     │ │ │ │    │ │ │ │
-- 17   A A A B     │ │ │ B    │ │ │ B     B 9  :  G B A
-- 18   A A A a     ├─┴─┴─╯    ├─┴─┴─╯
-- 19   A           A          A           A 10  :  EDCB A
--
--
-- 01   G      G          G            G 1  :  _ G C
-- 02   c      │          │
-- 03   C F    │ F        │ F          F 2  :  _ F D
-- 04   C d    │ │        │ │
-- 05   C D E  │ │ E      │ │ E        E 3  :  _ E C
-- 06   C D c  │ │ │      │ │ │
-- 07   C D C  │ D │      ├─D │        D 4  :  F D CB
-- 08   c b C  ├─┼─╯      ├─│─╯
-- 09   C B    C │        C │          C 5  :  GED C A
-- 10   a B    │ │        │ │
-- 11   A B    │ B        │ B          B 6  :  D B A
-- 12   A a    ├─╯        ├─╯
-- 13   A      A          A            A 7  :  CB A

--
--  ------  result  ------
-- 01   E        E           E─╮         E 1  :  _ E AB
-- 02   a b      ├─╮         │ │
-- 03   A B D    │ │ D       │ │ D       D 2  :  _ D B
-- 04   A B b    │ │ │       │ │ │
-- 05   A B B C  │ │ │ C     │ │ │ C     C 3  :  _ C B
-- 06   A B B b  │ ├─┴─╯     │ ├─┴─╯
-- 07   A B      │ B         │ B         B 4  :  EDC B A
-- 08   A a      ├─╯         ├─╯
-- 09   A        A           A           A 5  :  EB A
--
--
-- 01   F         F           F           F 1  :  _ F B
-- 02   b         │           │
-- 03   B E       │ E         │ E─┬─╮     E 2  :  _ E BDC
-- 04   B b d c   │ ├─┬─╮     │ │ │ │
-- 05   B B D C   │ │ D │     │ │ D │     D 3  :  E D A
-- 06   B B a C   │ │ │ │     │ │ │ │
-- 07   B B A C   │ │ │ C     │ │ │ C     C 4  :  E C A
-- 08   B B A a   ├─╯ │ │     ├─╯ │ │
-- 09   B   A A   B   │ │     B   │ │     B 5  :  FE B A
-- 10   a   A A   ├───┴─╯     ├───┴─╯
-- 11   A         A           A           A 6  :  DCB A
--
--
-- 01   H          H            H           H 1  :  _ H E
-- 02   e          │            │
-- 03   E G        │ G          │ G         G 2  :  _ G E
-- 04   E e        │ │          │ │
-- 05   E E F      │ │ F        ├─│─F─╮     F 3  :  _ F EDC
-- 06   e E d c    ├─┴─┼─╮      ├─╯ │ │
-- 07   E   D C    E   │ │      E   │ │     E 4  :  HGF E B
-- 08   b   D C    │   │ │      │   │ │
-- 09   B   D C    │   D │      │   D │     D 5  :  F D A
-- 10   B   a C    │   │ │      │   │ │
-- 11   B   A C    │   │ C      │   │ C     C 6  :  F C A
-- 12   B   A a    │   │ │      │   │ │
-- 13   B   A A    B   │ │      B   │ │     B 7  :  E B A
-- 14   a   A A    ├───┴─╯      ├───┴─╯
-- 15   A          A            A           A 8  :  DCB A
--
--
-- 01   G          G            G─┬─┬─┬─╮     G 1  :  _ G DCBFE
-- 02   d c b f e  ├─┬─┬─┬─╮    │ │ │ │ │
-- 03   D C B F E  │ │ │ F │    │ │ │ F │     F 2  :  G F E
-- 04   D C B e E  │ │ │ ├─╯    │ │ │ ├─╯
-- 05   D C B E    │ │ │ E      │ │ │ E       E 3  :  GF E D
-- 06   D C B d    ├─│─│─╯      ├─│─│─╯
-- 07   D C B      D │ │        D─┤ │         D 4  :  GE D CA
-- 08   a c B      ├─┤ │        │ │ │
-- 09   A C B      │ C │        │ C │         C 5  :  GD C A
-- 10   A a B      │ │ │        │ │ │
-- 11   A A B      │ │ B        │ │ B         B 6  :  G B A
-- 12   A A a      ├─┴─╯        ├─┴─╯
-- 13   A          A            A             A 7  :  DCB A
--
--
-- 01   G                   G                   G 1  :  _ G ABFCDE
-- 02   a b f c d e         ├─┬─┬─┬─┬─╮
-- 03   A B F C D E         │ │ F │ │ │         F 2  :  G F DCEB
-- 04   A B b c d e         │ │ ├─┼─┼─┤
-- 05   A B B C D E         │ │ │ │ │ E         E 3  :  GF E ACB
-- 06   A B B C D a c b     │ │ │ │ │ ├─┬─╮
-- 07   A B B C D A C B     │ │ │ │ D │ │ │     D 4  :  GF D A
-- 08   A B B C a A C B     │ │ │ ├─│─│─╯ │
-- 09   A B B C A A   B     │ │ │ C │ │   │     C 5  :  GFE C B
-- 10   A B B b A A   B     │ ├─┴─┴─│─│───╯
-- 11   A B     A A         │ B     │ │         B 6  :  GFEC B A
-- 12   A a     A A         ├─┴─────┴─╯
-- 13   A                   A                   A 7  :  GEDB A
--
--
--
-- 01   G             G             G 1  :  _ G EAFDC
-- 02   e a f d c     ├─┬─┬─┬─╮
-- 03   E A F D C     │ │ F │ │     F 2  :  G F DEA
-- 04   e A a d C     ├─│─┼─┤ │
-- 05   E A A D C     E │ │ │ │     E 3  :  GF E C
-- 06   c A A D C     │ │ │ │ │
-- 07   C A A D C     │ │ │ D │     D 4  :  GF D CA
-- 08   c A A a C     ├─│─│─┼─╯
-- 09   C A A A       C │ │ │       C 5  :  GED C B
-- 10   b A A A       │ │ │ │
-- 11   B A A A       B │ │ │       B 6  :  C B A
-- 12   a A A A       ├─┴─┴─╯
-- 13   A             A             A 7  :  GFDB A
--
--
-- 01   G                 G                 G 1  :  _ G BFDEAC
-- 02   b f d e a c       ├─┬─┬─┬─┬─╮
-- 03   B F D E A C       │ F │ │ │ │       F 2  :  G F ECBA
-- 04   B b D e a c       │ ├─│─┼─┼─┤
-- 05   B B D E A C       │ │ │ E │ │       E 3  :  GF E ACB
-- 06   B B D a A c b     │ │ │ ├─│─┼─╮
-- 07   B B D A A C B     │ │ D │ │ │ │     D 4  :  G D CA
-- 08   B B c a A C B     │ │ ├─┼─│─╯ │
-- 09   B B C A A   B     │ │ C │ │   │     C 5  :  GFED C B
-- 10   B B b A A   B     ├─┴─┴─│─│───╯
-- 11   B     A A         B     │ │         B 6  :  GFEC B A
-- 12   a     A A         ├─────┴─╯
-- 13   A                 A                 A 7  :  GFEDB A
--
--
--
--  ------  result  ------
-- 01   H               H               H 1  :  _ H CG
-- 02   c g             ├─╮
-- 03   C G             │ G             G 2  :  H G C
-- 04   C c             │ │
-- 05   C C F           │ │ F           F 3  :  _ F BE
-- 06   C C b e         │ │ ├─╮
-- 07   C C B E         │ │ │ E         E 4  :  F E BD
-- 08   C C B b d       │ │ │ ├─╮
-- 09   C C B B D       │ │ │ │ D       D 5  :  E D BA
-- 10   C C B B b a     ├─╯ │ │ ├─╮
-- 11   C   B B B A     C   │ │ │ │     C 6  :  HG C B
-- 12   b   B B B A     ├───┴─┴─╯ │
-- 13   B         A     B         │     B 7  :  FEDC B A
-- 14   a         A     ├─────────╯
-- 15   A               A               A 8  :  DB A
--
--
--
--  ------  result  ------
-- 01   H       H       H 1  :  _ H F
-- 02   f       │
-- 03   F G     │ G     G 2  :  _ G D
-- 04   F d     │ │
-- 05   F D     F │     F 3  :  H F E
-- 06   e D     │ │
-- 07   E D     E │     E 4  :  F E B
-- 08   b D     │ │
-- 09   B D     │ D     D 5  :  G D C
-- 10   B c     │ │
-- 11   B C     │ C     C 6  :  D C
-- 12   B       │
-- 13   B       B       B 7  :  E B A
-- 14   a       │
-- 15   A       A       A 8  :  B A
--
--
--
-- 01   G                   G                   G 1  :  _ G ADBEF
-- 02   a d b e f           ├─┬─┬─┬─╮
-- 03   A D B E F           │ │ │ │ F           F 2  :  G F CADEB
-- 04   A D B e c a d b     │ │ │ ├─┼─┬─┬─╮
-- 05   A D B E C A D B     │ │ │ E │ │ │ │     E 3  :  GF E DA
-- 06   A D B d C a D B     │ ├─│─┴─│─┼─╯ │
-- 07   A D B   C A   B     │ D │   │ │   │     D 4  :  GFE D BC
-- 08   A c b   C A   B     │ ├─┼───╯ │   │
-- 09   A C B     A   B     │ C │     │   │     C 5  :  FD C BA
-- 10   A b B     a   B     │ ├─┴─────┼───╯
-- 11   A B       A         │ B       │         B 6  :  GFDC B A
-- 12   A a       A         ├─┴───────╯
-- 13   A                   A                   A 7  :  GFECB A
--
--
-- 01   G                 G                     G─┬─┬─┬─┬─╮         G 1  :  _ G BDECFA
-- 02   b d e c f a       ├─┬─┬─┬─┬─╮           │ │ │ │ │ │
-- 03   B D E C F A       │ │ │ │ F │           │ │ ├─│─F─┼─┬─╮     F 2  :  G F BECAD
-- 04   B D e C b a c d   │ │ ├─│─┼─┼─┬─╮       │ │ │ │ │ │ │ │
-- 05   B D E C B A C D   │ │ E │ │ │ │ │       │ ├─E─│─┤─┤ │ │     E 3  :  GF E BAD
-- 06   B D d C b a C D   │ ├─┴─│─┼─┼─│─╯       │ ├───│─│─│─│─╯
-- 07   B D   C B A C     │ D   │ │ │ │         │ D   │ │ │ │       D 4  :  GFE D C
-- 08   B c   C B A C     │ ├───┴─│─│─╯         │ ├───┴─│─│─╯
-- 09   B C     B A       │ C     │ │           │ C     │ │         C 5  :  GFD C AB
-- 10   B b     B a       ├─┴─────┴─┤           ├─┴─────┴─┤
-- 11   B         A       B         │           B         │         B 6  :  GFEC B A
-- 12   a         A       ├─────────╯           ├─────────╯
-- 13   A                 A                     A                   A 7  :  GFECB A
--

---@param scenario string[]
---@param show_graph? boolean
---@param symbols I.GGSymbols
---@param fields I.GGVarName[]
---@return string[]
---@return boolean -- true if contains bi-crossing
local function run_test_scenario(scenario, show_graph, symbols, fields)
  ---@type I.RawCommit[]
  local raw = {}
  for i, r in ipairs(scenario) do
    local iter = r:gmatch('[^%s]+')
    local hash = iter()
    local par_iter = (iter() or ''):gmatch('.')
    local parents = {}
    for parent in par_iter do
      parents[#parents + 1] = parent
    end

    raw[#raw + 1] = {
      msg = hash,
      hash = hash,
      parents = parents,
      branch_names = {},
      tags = {},
      author_name = '',
      author_date = tostring(i),
    }
  end

  local options = { mode = (show_graph and 'debug' or 'test') }
  local _, lines, _, _, found_bi_crossing = core._gitgraph(raw, options, symbols, fields)

  return lines, found_bi_crossing
end

---@param symbols I.GGSymbols
---@param fields I.GGVarName[]
---@return string[]
---@return boolean
function M.run_random(symbols, fields)
  local random_scenario = require('gitgraph.random')
  local commits = random_scenario()
  return run_test_scenario(commits, true, symbols, fields)
end

---@param symbols I.GGSymbols
---@param fields I.GGVarName[]
---@return string[]
---@return boolean
function M.run_tests(symbols, fields)
  local res = {}
  local failures = 0

  local function report_failure(msg)
    res[#res + 1] = msg
  end

  local scenarios = require('gitgraph.tests').scenarios

  local subset = {}
  for _, scenario in ipairs(scenarios) do
    -- if scenario.name == 'strange 2' then
    subset[#subset + 1] = scenario
    -- end
  end

  for _, scenario in ipairs(subset) do
    res[#res + 1] = ' ------ ' .. scenario.name .. ' ------ '

    for _, com in ipairs(scenario.commits) do
      res[#res + 1] = com
    end

    res[#res + 1] = ' ------ ' .. ' result ' .. ' ------ '

    local graph, found_bi_crossing = run_test_scenario(scenario.commits, true, symbols, fields)

    if found_bi_crossing then
      res[#res + 1] = ' >>>>>> ' .. ' bi-crossing ' .. ' <<<<<< '
    end

    for i, line in ipairs(graph) do
      res[#res + 1] = string.format('%02d', i) .. '   ' .. line
    end

    local fail = false

    for i, line in ipairs(graph) do
      if scenario.ignore ~= true and scenario.expect and line ~= scenario.expect[i] then
        report_failure('------ FAILURE ------')
        report_failure('failure in scenario ' .. scenario.name .. ' at line ' .. tostring(i))
        report_failure('expected:')
        report_failure('    ' .. (scenario.expect[i] or 'NA'))
        report_failure('got:')
        report_failure('    ' .. line)
        report_failure('---------------------')
        fail = true
      end
    end

    if fail then
      failures = failures + 1
    end

    res[#res + 1] = ''
  end

  if failures > 0 then
    report_failure(tostring(failures) .. ' failures')
  end

  report_failure(tostring(#scenarios - failures) .. ' of ' .. tostring(#scenarios) .. ' tests passed')

  return res, failures > 0
end

return M
