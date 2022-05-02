/-
Copyright (c) 2018 Jeremy Avigad. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Jeremy Avigad, Simon Hudon
-/
import Qpf.MvFunctor
import Qpf.PFunctor.Multivariate.Basic
import Qpf.PFunctor.Multivariate.M
import Qpf.Qpf.Multivariate.Basic
import Qpf.Qpf.Multivariate.Constructions.Const
import Qpf.MathlibPort.Quot

/-!
# The final co-algebra of a multivariate qpf is again a qpf.

For a `(n+1)`-ary QPF `F (α₀,..,αₙ)`, we take the least fixed point of `F` with
regards to its last argument `αₙ`. The result is a `n`-ary functor: `fix F (α₀,..,αₙ₋₁)`.
Making `fix F` into a functor allows us to take the fixed point, compose with other functors
and take a fixed point again.

## Main definitions

 * `Cofix.mk`     - constructor
 * `Cofix.dest    - destructor
 * `Cofix.corec`  - corecursor: useful for formulating infinite, productive computations
 * `Cofix.bisim`  - bisimulation: proof technique to show the equality of possibly infinite values
                    of `Cofix F α`

## Implementation notes

For `F` a QPF`, we define `Cofix F α` in terms of the M-type of the polynomial functor `P` of `F`.
We define the relation `Mcongr` and take its quotient as the definition of `Cofix F α`.

`Mcongr` is taken as the weakest bisimulation on M-type.  See
[avigad-carneiro-hudon2019] for more details.

## Reference

 * Jeremy Avigad, Mario M. Carneiro and Simon Hudon.
   [*Data Types as Quotients of Polynomial Functors*][avigad-carneiro-hudon2019]
-/


universe u

open_locale MvFunctor

namespace MvQpf

open TypeVec MvPFunctor

open MvFunctor (Liftp Liftr Liftr')

section Cofix
variable {n : ℕ} {F : TypeVec.{u} (n + 1) → Type u} [MvFunctor F] [q : MvQpf F]

/-- `corecF` is used as a basis for defining the corecursor of `Cofix F α`. `corecF`
uses corecursion to construct the M-type generated by `q.P` and uses function on `F`
as a corecursive step -/
def corecF {α : TypeVec n} {β : Type _} (g : β → F (α.append1 β)) : β → q.P.M α :=
  M.corec _ fun x => repr (g x)

theorem corecF_eq {α : TypeVec n} {β : Type _} (g : β → F (α.append1 β)) (x : β) :
    M.dest q.P (corecF g x) = appendFun id (corecF g) <$$> repr (g x) := by
  rw [corecF, M.dest_corec]

/-- Characterization of desirable equivalence relations on M-types -/
def IsPrecongr {α : TypeVec n} (r : q.P.M α → q.P.M α → Prop) : Prop :=
  ∀ ⦃x y⦄, r x y → abs (appendFun id (Quot.mk r) <$$> M.dest q.P x) = abs (appendFun id (Quot.mk r) <$$> M.dest q.P y)

/-- Equivalence relation on M-types representing a value of type `Cofix F` -/
def Mcongr {α : TypeVec n} (x y : q.P.M α) : Prop :=
  ∃ r, IsPrecongr r ∧ r x y

/-- Greatest fixed point of functor F. The result is a functor with one fewer parameters
than the input. For `F a b c` a ternary functor, fix F is a binary functor such that

```lean
Cofix F a b = F a b (Cofix F a b)
```
-/
def Cofix (F : TypeVec (n + 1) → Type u) [MvFunctor F] [q : MvQpf F] (α : TypeVec n) :=
  Quot (@Mcongr _ F _ q α)

instance {α : TypeVec n} [Inhabited q.P.A] [∀ i : Fin2 n, Inhabited (α i)] : Inhabited (Cofix F α) :=
  ⟨Quot.mk _ default⟩

/-- maps every element of the W type to a canonical representative -/
def mrepr {α : TypeVec n} : q.P.M α → q.P.M α :=
  corecF (abs ∘ M.dest q.P)

/-- the map function for the functor `Cofix F` -/
def Cofix.map {α β : TypeVec n} (g : α ⟹ β) : Cofix F α → Cofix F β :=
  Quot.lift (fun x : q.P.M α => Quot.mk Mcongr (g <$$> x))
    (by
      rintro aa₁ aa₂ ⟨r, pr, ra₁a₂⟩
      apply Quot.sound
      let r' := fun b₁ b₂ => ∃ a₁ a₂ : q.P.M α, r a₁ a₂ ∧ b₁ = g <$$> a₁ ∧ b₂ = g <$$> a₂
      refine ⟨r', ?_⟩
      constructor
      · show IsPrecongr r'
        rintro b₁ b₂ ⟨a₁, a₂, ra₁a₂, b₁eq, b₂eq⟩
        let u : Quot r → Quot r' :=
          Quot.lift (fun x : q.P.M α => Quot.mk r' (g <$$> x))
            (by
              intro a₁ a₂ ra₁a₂
              apply Quot.sound
              exact ⟨a₁, a₂, ra₁a₂, rfl, rfl⟩)
        have hu : (Quot.mk r' ∘ fun x : q.P.M α => g <$$> x) = u ∘ Quot.mk r := by
          ext x
          rfl
        rw [b₁eq, b₂eq, M.dest_map, M.dest_map, ← q.P.comp_map, ← q.P.comp_map]
        rw [← append_fun_comp, id_comp, hu, ← comp_id g, append_fun_comp]
        rw [q.P.comp_map, q.P.comp_map, abs_map, pr ra₁a₂, ← abs_map]
        
      show r' (g <$$> aa₁) (g <$$> aa₂)
      exact ⟨aa₁, aa₂, ra₁a₂, rfl, rfl⟩)

instance Cofix.instMvFunctor : MvFunctor (Cofix F) where
  map := @Cofix.map _ _ _ _

/-- Corecursor for `Cofix F` -/
def Cofix.corec {α : TypeVec n} {β : Type u} (g : β → F (α.append1 β)) : β → Cofix F α := fun x =>
  Quot.mk _ (corecF g x)


/-- Destructor for `Cofix F` -/
def Cofix.dest {α : TypeVec n} : Cofix F α → F (α.append1 (Cofix F α)) :=
  Quot.lift (fun x => appendFun id (Quot.mk Mcongr) <$$> abs (M.dest q.P x))
    (by
      rintro x y ⟨r, pr, rxy⟩
      simp
      have : ∀ x y, r x y → Mcongr x y := by
        intro x y h
        exact ⟨r, pr, h⟩
      rw [← Quot.factor_mk_eq _ _ this]
      simp
      conv => rw [append_fun_comp_id, comp_map, ← abs_map, pr rxy, abs_map, ← comp_map, ← append_fun_comp_id])

/-- Abstraction function for `Cofix F α` -/
def Cofix.abs {α} : q.P.M α → Cofix F α :=
  Quot.mk _

/-- Representation function for `Cofix F α` -/
def Cofix.repr {α} : Cofix F α → q.P.M α :=
  M.corec _ <| q.repr ∘ Cofix.dest

/-- Corecursor for `Cofix F` -/
def Cofix.corec'₁ {α : TypeVec n} {β : Type u} (g : ∀ {X}, (β → X) → F (α.append1 X)) (x : β) : Cofix F α :=
  Cofix.corec (fun x => g id) x

/-- More flexible corecursor for `Cofix F`. Allows the return of a fully formed
value instead of making a recursive call -/
def Cofix.corec' {α : TypeVec n} {β : Type u} (g : β → F (α.append1 (Sum (Cofix F α) β))) (x : β) : Cofix F α :=
  let f : (α ::: Cofix F α) ⟹ (α ::: Sum (Cofix F α) β) := id ::: Sum.inl
  Cofix.corec (Sum.elim (MvFunctor.map f ∘ Cofix.dest) g) (Sum.inr x : Sum (Cofix F α) β)

/-- Corecursor for `Cofix F`. The shape allows recursive calls to
look like recursive calls. -/
def Cofix.corec₁ {α : TypeVec n} {β : Type u} (g : ∀ {X}, (Cofix F α → X) → (β → X) → β → F (α ::: X)) (x : β) :
    Cofix F α :=
  Cofix.corec' (fun x => g Sum.inl Sum.inr x) x

theorem Cofix.dest_corec {α : TypeVec n} {β : Type u} (g : β → F (α.append1 β)) (x : β) :
    Cofix.dest (Cofix.corec g x) = appendFun id (Cofix.corec g) <$$> g x := by
  conv => lhs rw [Cofix.dest, Cofix.corec]
  simp
  rw [corecF_eq, abs_map, abs_repr, ← comp_map, ← append_fun_comp]
  rfl

/-- constructor for `Cofix F` -/
def Cofix.mk {α : TypeVec n} : F (α.append1 <| Cofix F α) → Cofix F α :=
  Cofix.corec fun x => (appendFun id fun i : Cofix F α => Cofix.dest.{u} i) <$$> x

/-!
## Bisimulation principles for `Cofix F`

The following theorems are bisimulation principles. The general idea
is to use a bisimulation relation to prove the equality between
specific values of type `Cofix F α`.

A bisimulation relation `R` for values `x y : Cofix F α`:

 * holds for `x y`: `R x y`
 * for any values `x y` that satisfy `R`, their root has the same shape
   and their children can be paired in such a way that they satisfy `R`.

-/

#check Quot.ind
-- #check Quot.ind_On

private theorem Cofix.bisim_aux {α : TypeVec n} (r : Cofix F α → Cofix F α → Prop) (h' : ∀ x, r x x)
    (h : ∀ x y, r x y → appendFun id (Quot.mk r) <$$> Cofix.dest x = appendFun id (Quot.mk r) <$$> Cofix.dest y) :
    ∀ x y, r x y → x = y := by
  intro x
  rcases x; clear x; rename M (P F) α => x;
  intro y
  rcases y; clear y; rename M (P F) α => y; 
  intro rxy
  apply Quot.sound
  let r' := fun x y => r (Quot.mk _ x) (Quot.mk _ y)
  sorry
  /-
  have : IsPrecongr r' := by
    intro a b r'ab
    have h₀ :
      appendFun id (Quot.mk r ∘ Quot.mk Mcongr) <$$> abs (M.dest q.P a) =
        appendFun id (Quot.mk r ∘ Quot.mk Mcongr) <$$> abs (M.dest q.P b) :=
      by
      rw [append_fun_comp_id, comp_map, comp_map] <;> exact h _ _ r'ab
    have h₁ : ∀ u v : q.P.M α, Mcongr u v → Quot.mk r' u = Quot.mk r' v := by
      intro u v cuv
      apply Quot.sound
      simp [r']
      rw [Quot.sound cuv]
      apply h'
    let f : Quot r → Quot r' :=
      Quot.lift (Quot.lift (Quot.mk r') h₁)
        (by
          intro c
          apply Quot.induction_on c
          clear c
          intro c d
          apply Quot.induction_on d
          clear d
          intro d rcd
          apply Quot.sound
          apply rcd)
    have : f ∘ Quot.mk r ∘ Quot.mk Mcongr = Quot.mk r' := rfl
    rw [← this, append_fun_comp_id, q.P.comp_map, q.P.comp_map, abs_map, abs_map, abs_map, abs_map, h₀]
  refine' ⟨r', this, rxy⟩
  -/

/-- Bisimulation principle using `map` and `quot.mk` to match and relate children of two trees. -/
theorem Cofix.bisim_rel {α : TypeVec n} (r : Cofix F α → Cofix F α → Prop)
    (h : ∀ x y, r x y → appendFun id (Quot.mk r) <$$> Cofix.dest x = appendFun id (Quot.mk r) <$$> Cofix.dest y) :
    ∀ x y, r x y → x = y := by
  let r' x y := x = y ∨ r x y
  intro x y rxy
  apply Cofix.bisim_aux r'
  · intro x
    apply Or.inl
    rfl
    
  · intro x y r'xy
    cases r'xy with
    | inl h => rw [h]
    | inr r'xy =>      
      have : ∀ x y, r x y → r' x y := fun x y h => Or.inr h
      rw [← Quot.factor_mk_eq _ _ this]
      simp
      rw [append_fun_comp_id]
      rw [@comp_map _ _ _ q _ _ _ (appendFun id (Quot.mk r)), @comp_map _ _ _ q _ _ _ (appendFun id (Quot.mk r))]
      rw [h _ _ r'xy]
    
  apply Or.inr
  exact rxy

#check rel_last

/-- Bisimulation principle using `liftr` to match and relate children of two trees. -/
theorem Cofix.bisim {α : TypeVec n} 
                    (r : Cofix F α → Cofix F α → Prop)
                    (h : ∀ x y, r x y → Liftr @(rel_last α r) (Cofix.dest x) (Cofix.dest y)) : 
    ∀ x y, r x y → x = y := by
  apply Cofix.bisim_rel
  intro x y rxy
  sorry
  /-
  rcases(liftr_iff (rel_last α r) _ _).mp (h x y rxy) with ⟨a, f₀, f₁, dxeq, dyeq, h'⟩  
  rw [dxeq, dyeq, ← abs_map, ← abs_map, MvPFunctor.map_eq, MvPFunctor.map_eq]
  rw [← split_drop_fun_last_fun f₀, ← split_drop_fun_last_fun f₁]
  rw [append_fun_comp_split_fun, append_fun_comp_split_fun]
  rw [id_comp, id_comp]
  congr 2 with i j
  cases' i with _ i <;> simp
  · apply Quot.sound
    apply h' _ j
    
  · change f₀ _ j = f₁ _ j
    apply h' _ j
  -/

/- FIXME
/-- Bisimulation principle using `liftr'` to match and relate children of two trees. -/
theorem Cofix.bisim₂ {α : TypeVec n} (r : Cofix F α → Cofix F α → Prop)
    (h : ∀ x y, r x y → Liftr' (rel_last' α r) (Cofix.dest x) (Cofix.dest y)) : 
    ∀ x y, r x y → x = y :=
  Cofix.bisim _ <| by
    intros <;> rw [← liftr_last_rel_iff] <;> apply h <;> assumption


/-- Bisimulation principle the values `⟨a,f⟩` of the polynomial functor representing
`Cofix F α` as well as an invariant `Q : β → Prop` and a state `β` generating the
left-hand side and right-hand side of the equality through functions `u v : β → Cofix F α` -/
theorem Cofix.bisim' {α : TypeVec n} {β : Type _} (Q : β → Prop) (u v : β → Cofix F α)
    (h : ∀ x, Q x → ∃ a f' f₀ f₁,
          Cofix.dest (u x) = abs ⟨a, q.P.append_contents f' f₀⟩ 
          ∧ Cofix.dest (v x) = abs ⟨a, q.P.append_contents f' f₁⟩ 
          ∧ ∀ i, ∃ x', Q x' ∧ f₀ i = u x' ∧ f₁ i = v x'
      ) :
    ∀ x, Q x → u x = v x := fun x Qx =>
  let R := fun w z : Cofix F α => ∃ x', Q x' ∧ w = u x' ∧ z = v x'
  Cofix.bisim R
    (fun x y ⟨x', Qx', xeq, yeq⟩ => by
      rcases h x' Qx' with ⟨a, f', f₀, f₁, ux'eq, vx'eq, h'⟩
      rw [liftr_iff]
      refine' ⟨a, q.P.append_contents f' f₀, q.P.append_contents f' f₁, xeq.symm ▸ ux'eq, yeq.symm ▸ vx'eq, _⟩
      intro i
      cases i
      · apply h'
        
      · intro j
        apply Eq.refl
        )
    _ _ ⟨x, Qx, rfl, rfl⟩

-/

theorem Cofix.mk_dest {α : TypeVec n} (x : Cofix F α) : Cofix.mk (Cofix.dest x) = x := by
  apply Cofix.bisim_rel (fun x y : Cofix F α => x = Cofix.mk (Cofix.dest y)) _ _ _ rfl
  simp
  intro x y h
  rw [h]
  conv => lhs congr skip rw [Cofix.mk]rw [Cofix.dest_corec]
  rw [← comp_map, ← append_fun_comp, id_comp]
  rw [← comp_map, ← append_fun_comp, id_comp, ← Cofix.mk]
  apply congrFun
  apply congrArg
  apply congrArg
  funext x
  apply Quot.sound
  rfl

theorem Cofix.dest_mk {α : TypeVec n} (x : F (α.append1 <| Cofix F α)) : Cofix.dest (Cofix.mk x) = x := by
  have : Cofix.mk ∘ Cofix.dest = @_root_.id (Cofix F α) := funext Cofix.mk_dest
  rw [Cofix.mk, Cofix.dest_corec, ← comp_map, ← Cofix.mk, ← append_fun_comp, this, id_comp, append_fun_id_id,
    MvFunctor.id_map]

theorem Cofix.ext {α : TypeVec n} (x y : Cofix F α) (h : x.dest = y.dest) : x = y := by
  rw [← Cofix.mk_dest x, h, Cofix.mk_dest]

theorem Cofix.ext_mk {α : TypeVec n} (x y : F (α ::: Cofix F α)) (h : Cofix.mk x = Cofix.mk y) : x = y := by
  rw [← Cofix.dest_mk x, h, Cofix.dest_mk]


end Cofix

/-!
`liftr_map`, `liftr_map_last` and `liftr_map_last'` are useful for reasoning about
the induction step in bisimulation proofs.
-/


section LiftrMap

open MvFunctor

theorem liftr_map {α β : TypeVec n} {F' : TypeVec n → Type u} [MvFunctor F'] [LawfulMvFunctor F']
    (R : β ⊗ β ⟹ Repeat n Prop) 
    (x : F' α) 
    (f g : α ⟹ β) 
    (h : α ⟹ Subtype_ R)
    (hh : subtypeVal _ ⊚ h = (f ⊗' g) ⊚ Prod.diag) : 
    Liftr' R (f <$$> x) (g <$$> x) := 
by
  rw [liftr_def]
  refine ⟨h <$$> x, ?_⟩
  rw [MvFunctor.map_map, comp_assoc, hh, ← comp_assoc, fst_prod_mk, comp_assoc, fst_diag]
  rw [MvFunctor.map_map, comp_assoc, hh, ← comp_assoc, snd_prod_mk, comp_assoc, snd_diag]
  simp [Liftr']

open Function
variable {F: TypeVec (n + 1) → Type u} [MvFunctor F]

theorem liftr_map_last  {α : TypeVec.{u} n}
                        {ι ι'}
                        (R : ι' → ι' → Prop) 
                        (x : F (α ::: ι))
                        (f g : ι → ι')
                        (hh : ∀ x : ι, R (f x) (g x)) : 
      Liftr' (relLast' _ R) ((id ::: f) <$$> x) ((id ::: g) <$$> x) :=
by
  sorry
  /- FIXME
  let h : ι → { x : ι' × ι' // uncurry R x } := fun x => ⟨(f x, g x), hh x⟩
  let b : (α ::: ι) ⟹ _ := @diagSub n α ::: h
  let c : (Subtype_ α.repeatEq ::: { x // uncurry R x }) 
          ⟹ ((fun i : Fin2 n => { x // ofRepeat (α.relLast' R i.fs x) }) ::: Subtype (uncurry R)) 
      := (ofSubtype _) ::: id
  have hh : subtypeVal _ ⊚ toSubtype _ ⊚ from_append1_drop_last ⊚ c ⊚ b = ((id ::: f) ⊗' (id ::: g)) ⊚ Prod.diag := 
  by
    have hb : b = @diagSub n α ::: h
      := by rfl
    have hc : c = ofSubtype (repeatEq α) ::: id
      := by rfl
    simp [hb, hc]
    apply eq_of_drop_last_eq
    · simp [prod_map_id, drop_fun_prod, drop_fun_append_fun, drop_fun_diag, id_comp, drop_fun_to_subtype]
      erw [to_subtype_of_subtype_assoc, id_comp]
      intro i
      funext x
      simp [diagSub, Prod.diag]
      induction i
      . rfl
      
      . rename_i n' i i_ih _ _
        simp [diagSub, Prod.diag, subtypeVal, *]
        apply i_ih
        apply @i_ih F' (cast _ PUnit.unit) (cast _ PUnit.unit) (cast _ PUnit.unit)
        
        
    simp [last_fun_from_append1_drop_last, last_fun_to_subtype, last_fun_append_fun, last_fun_subtype_val,
          comp.left_id, last_fun_comp, last_fun_prod]
    ext1
    rfl
  apply liftr_map _ _ _ _ (toSubtype _ ⊚ from_append1_drop_last ⊚ c ⊚ b) hh


theorem liftr_map_last' [LawfulMvFunctor F] {α : TypeVec n} {ι} (R : ι → ι → Prop) (x : F (α ::: ι)) (f : ι → ι)
    (hh : ∀ x : ι, R (f x) x) : Liftr' (relLast' _ R) ((id ::: f) <$$> x) x := by
  have := liftr_map_last R x f id hh
  rwa [append_fun_id_id, MvFunctor.id_map] at this

-/

end LiftrMap

variable {F: TypeVec (n + 1) → Type u} [MvFunctor F] [LawfulMvFunctor F] [q : MvQpf F]

theorem Cofix.abs_repr {α} (x : Cofix F α) : Quot.mk _ (Cofix.repr x) = x := by
  sorry 
/- FIXME
  let R := fun x y : Cofix F α => Cofix.abs (Cofix.repr y) = x
  refine' Cofix.bisim₂ R _ _ _ rfl
  clear x
  rintro x y h
  simp [R]  at h
  subst h
  simp [Cofix.dest, Cofix.abs]
  induction y using Quot.ind
  simp only [Cofix.repr, M.dest_corec, abs_map, abs_repr]
  conv => congr skip rw [Cofix.dest]
  simp
  rw [MvFunctor.map_map, MvFunctor.map_map, ← append_fun_comp_id, ← append_fun_comp_id]
  let f : (α ::: (P F).M α) ⟹ subtype_ (α.rel_last' R) :=
    split_fun diag_sub fun x => ⟨(Cofix.abs (Cofix.abs x).repr, Cofix.abs x), _⟩
  refine' liftr_map _ _ _ _ f _
  · simp only [← append_prod_append_fun, prod_map_id]
    apply eq_of_drop_last_eq
    · simp
      simp only [drop_fun_diag]
      erw [subtype_val_diag_sub]
      
    ext1
    simp only [Cofix.abs, Prod.mk.inj_iffₓ, prod_mapₓ, Function.comp_app, last_fun_append_fun, last_fun_subtype_val,
      last_fun_comp, last_fun_split_fun]
    simp [drop_fun_rel_last, last_fun, prod.diag]
    constructor <;> rfl
    
  simp [rel_last', split_fun, Function.uncurry, R]
  rfl
-/

section Tactic

-- setup_tactic_parser

open Tactic

omit q

/- FIXME
/-- tactic for proof by bisimulation -/
unsafe def mv_bisim (e : parse texpr) (ids : parse with_ident_list) : tactic Unit := do
  let e ← to_expr e
  let expr.pi n bi d b ←
    retrieve <| do
        generalize e
        target
  let quote.1 (@Eq (%%ₓt) (%%ₓl) (%%ₓr)) ← pure b
  let x ← mk_local_def `n d
  let v₀ ← mk_local_def `a t
  let v₁ ← mk_local_def `b t
  let x₀ ← mk_app `` Eq [v₀, l.instantiate_var x]
  let x₁ ← mk_app `` Eq [v₁, r.instantiate_var x]
  let xx ← mk_app `` And [x₀, x₁]
  let ex ← lambdas [x] xx
  let ex ← mk_app `` Exists [ex] >>= lambdas [v₀, v₁]
  let R ← pose `R none ex
  refine (pquote.1 (Cofix.bisim₂ (%%ₓR) _ _ _ ⟨_, rfl, rfl⟩))
  let f (a b : Name) : Name := if a = `_ then b else a
  let ids := (ids ++ List.repeat `_ 5).zipWith f [`a, `b, `x, `Ha, `Hb]
  let (ids₀, w :: ids₁) ← pure <| List.splitAtₓ 2 ids
  intro_lst ids₀
  let h ← intro1
  let [(_, [w, h], _)] ← cases_core h [w]
  cases h ids₁
  pure ()

run_cmd
  add_interactive [`` mv_bisim]
-/

end Tactic

/- FIXME
theorem corec_roll {α : TypeVec n} {X Y} {x₀ : X} (f : X → Y) (g : Y → F (α ::: X)) :
    Cofix.corec (g ∘ f) x₀ = Cofix.corec (MvFunctor.map (id ::: f) ∘ g) (f x₀) := by
  mv_bisim x₀
  rw [Ha, Hb, Cofix.dest_corec, Cofix.dest_corec]
  rw [MvFunctor.map_map, ← append_fun_comp_id]
  refine' liftr_map_last _ _ _ _ _
  intro a
  refine' ⟨a, rfl, rfl⟩

theorem Cofix.dest_corec' {α : TypeVec n} {β : Type u} (g : β → F (α.append1 (Sum (Cofix F α) β))) (x : β) :
    Cofix.dest (Cofix.corec' g x) = appendFun id (Sum.elim id (Cofix.corec' g)) <$$> g x := by
  rw [Cofix.corec', Cofix.dest_corec]
  simp
  congr with (i | i) <;> rw [corec_roll] <;> simp [Cofix.corec']
  · mv_bisim i
    rw [Ha, Hb, Cofix.dest_corec]
    simp [(· ∘ ·)]
    repeat'
      rw [MvFunctor.map_map, ← append_fun_comp_id]
    apply liftr_map_last'
    simp [(· ∘ ·), R]
    intros
    exact ⟨_, rfl, rfl⟩
    
  · congr with y
    erw [append_fun_id_id]
    simp [MvFunctor.id_map]


theorem Cofix.dest_corec₁ {α : TypeVec n} 
                          {β : Type u} 
                          (g : ∀ {X}, (Cofix F α → X) → (β → X) → β → F (α.append1 X))
                          (x : β) 
                          (h : ∀ X Y (f : Cofix F α → X) (f' : β → X) (k : X → Y), g (k ∘ f) (k ∘ f') x = (id ::: k) <$$> g f f' x) :
    Cofix.dest (Cofix.corec₁ (@g) x) = g id (Cofix.corec₁ @g) x := by
  rw [Cofix.corec₁, Cofix.dest_corec', ← h] <;> rfl
-/

instance mvqpfCofix : MvQpf (Cofix F) where
  P         := q.P.Mp
  abs       := @fun α => Quot.mk Mcongr
  repr      := @fun α => Cofix.repr
  abs_repr  := @fun α => Cofix.abs_repr
  abs_map   := @fun α β g x => rfl

end MvQpf

