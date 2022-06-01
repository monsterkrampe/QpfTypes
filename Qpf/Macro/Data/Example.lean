
import Qpf.Macro.Data
import Mathlib

set_option trace.Meta.debug true
set_option pp.rawOnError true


data MyList (α : Type 1) (β : Type 2) : Type _
  | Nil   : MyList α β
  | Cons : {a : α × α} → (as : MyList α β) → MyList α β

#check MyList.HeadT
#check MyList.HeadT.Nil
#print MyList.HeadT 


-- data Tree' (α β : Type 2) : Type _
--   | Nil  : Tree' α β
--   | Node : (a : α) → (β → Tree' α β) → Tree' α β

-- #print Tree'.HeadT

-- #print MyList
-- #print MyList'