--		Copyright 1995 by Daniel R. Grayson and Michael Stillman

koszul(ZZ, Matrix) := (i,m) -> (
     sendgg(ggPush m, ggINT, gg i, ggkoszul);
     getMatrix ring m)

document { quote koszul,
     TT "koszul(i,f)", " -- provides the i-th differential in the Koszul complex
     associated to f.",
     PARA,
     "Here f should be a 1 by n matrix."
     }

symmetricPower(ZZ, Matrix) := (i,m) -> (
     sendgg(ggPush m, ggINT, gg i, ggsymm);
     getMatrix ring m)

document { quote symmetricPower,
     TT "symmetricPower(i,f)", " -- provides the i-th symmetric power of the matrix f.",
     PARA,
     "Here f should be a 1 by n matrix."
     }

MinorsComputation = new SelfInitializingType of BasicList

document { quote MinorsComputation,
     TT "MinorsComputation", " -- a type of self initializing list used
     internally by ", TO "minors", "."
     }

PfaffiansComputation = new SelfInitializingType of BasicList

document { quote PfaffiansComputation,
     TT "PfaffiansComputation", " -- a type of self initializing list used
     internally by ", TO "pfaffians", "."
     }

exteriorPower(ZZ,Module) := (p,M) -> (
     R := ring M;
     if p < 0 then R^0
     else if p === 0 then R^1
     else if p === 1 then M
     else (
	  if isFreeModule M then (
	       sendgg(ggPush M, ggPush p, ggexterior);
	       new Module from R)
	  else (
	       m := presentation M;
	       F := target m;
	       G := source m;
	       Fp1 := exteriorPower(p-1,F);
	       Fp := exteriorPower(p,F);
	       h1 := m ** id_Fp1;
	       h2 := wedgeProduct(1,p-1,F);
	       coker (h2*h1))))

exteriorPower(ZZ, Matrix) := (p,m) -> (
     R := ring m;
     if p < 0 then map(R^0,R^0,0)
     else if p === 0 then map(R^1,R^1,1)
     else if p === 1 then m
     else (
	  -- h := prune m;
	  h := m;			  -- DRG: disabled 'prune' here.
	  h1 := matrix h;
	  sendgg(ggPush h1, ggPush p, ggexterior);
	  hp := getMatrix ring m;
	  map(exteriorPower(p, target h),
	      exteriorPower(p, source h),
	      hp))
    )

TEST "
R = ZZ/101
exteriorPower(3,R^5)
R = ZZ/101[a..d]
I = monomialCurve(R,{1,3,4})
M = Ext^2(coker generators I, R)
prune exteriorPower(3,M)
exteriorPower(0,R^3)
exteriorPower(0,M)
prune exteriorPower(1,M)
exteriorPower(2,M)
exteriorPower(-1,M)
exteriorPower(-2,M)

M = subquotient(matrix{{a,b,c}}, matrix{{a^2,b^2,c^2,d^2}})
N = subquotient(matrix{{a^2,b^2,c^2}}, matrix{{a^3,b^3,c^3,d^3}})
m = map(N,M,matrix(R,{{1,0,0},{0,1,0},{0,0,1}}))
source m
target m
trim ker m
M1 = coker presentation M
N1 = coker presentation N
m1 = map(N1,M1,matrix m)
M2 = trim exteriorPower(2,M)
N2 = trim exteriorPower(2,N)
"

TEST "
R = ZZ/101[a .. i]
m = genericMatrix(R,a,3,3)
assert( exteriorPower(1,m) == m )
assert( minors(1,m) == image vars R )
assert( exteriorPower(2,m*m) == exteriorPower(2,m)*exteriorPower(2,m) )
assert( 
     exteriorPower(2,m)
     == 
     matrix {
	  {-b*d+a*e, -b*g+a*h, -e*g+d*h},
	  {-c*d+a*f, -c*g+a*i, -f*g+d*i},
	  {-c*e+b*f, -c*h+b*i, -f*h+e*i}} )
assert( exteriorPower(3,m) == matrix {{-c*e*g+b*f*g+c*d*h-a*f*h-b*d*i+a*e*i}} )
"

wedgeProduct = method()
wedgeProduct(ZZ,ZZ,Module) := (p,q,M) -> (
     if isFreeModule M then (
	  R := ring M;
	  sendgg(ggPush p, ggPush q, ggPush M, ggexteriorproduct);
	  getMatrix R)
     else map(exteriorPower(p+q,M),exteriorPower(p,M)**exteriorPower(q,M),wedgeProduct(p,q,cover M)))

document { quote wedgeProduct,
     TT "wedgeProduct(p,q,M)", " -- returns the matrix which represents the
     multiplication map from ", TT "exteriorPower(p,M) ** exteriorPower(q,M)", "
     to ", TT "exteriorPower(p+q,M)", ".",
     PARA,
     "Here ", TT "M", " is free module."
     }

minors = method(Options => { Limit => infinity })

minors(ZZ,Matrix) := (j,m,options) -> (
     if j === 0 then ideal 1_(ring m)
     else if j < 0 then ideal 0_(ring m)
     else (
	  comp := MinorsComputation{j};
	  if not m#?comp then (
	      sendgg(
		   ggPush m,			  -- m
		   ggINT, gg j,		  -- m j
		   ggdets);			  -- create computation
	      m#comp = {1, newHandle()};       -- the '1' means: not done yet.
	     );
	  if m#comp#0 =!= 0 then (
	      nsteps := if options.Limit === infinity then -1 else options.Limit;
	      sendgg(
		   ggPush m#comp#1,
		   ggPush nsteps,
		   ggcalc);
	      m#comp = {eePopInt(), m#comp#1}   -- return code: 0 means done, != 0 means more left
	      );
	  sendgg(ggPush m#comp#1,
		 ggINT, gg 0,
		 ggindex);
	  ideal getMatrix ring m
	  ))

document { quote exteriorPower,
     TT "exteriorPower(i,M)", " -- the i-th exterior power of a module ", TT "M", ".",
     BR,NOINDENT,
     TT "exteriorPower(i,f)", " -- the i-th exterior power of a matrix ", TT "f", ".",
     PARA,
     "The rows and columns are indexed in the same order as that used by
     ", TO "subsets", " when listing the subsets of a set.",
     PARA,
     "When ", TT "i", " is ", TT "1", ", then the result is equal to ", TT "M", ".",
     PARA,
     "When M is not a free module, then the generators used for the result
     will be wedges of the generators of M.  In other words, the modules
     ", TT "cover exteriorPower(i,M)", " and ", TT "exteriorPower(i,cover M)", " 
     will be equal.",
     PARA,
     SEEALSO {"minors", "det", "wedgeProduct"}
     }

TEST ///
    R = ZZ[x,y,z]
    modules = {
	 image matrix {{x^2,x,y}},
	 coker matrix {{x^2,y^2,0},{0,y,z}},
	 R^{-1,-2,-3},
	 image matrix {{x,y}} ++ coker matrix {{y,z}}
	 }
    scan(modules, M -> assert( cover exteriorPower(2,M) == exteriorPower(2,cover M) ))
///


document { quote minors,
     TT "minors(j,m)", " -- produces the ideal generated by
     the determinants of the j-by-j submatrices of the matrix m.",
     PARA,
     "Options:",
     MENU {
	  TO "Limit"
	  },
     PARA,
     "Uses:",
     MENU {
	  TO "MinorsComputation"
	  },
     PARA,
     SEEALSO {"det", "exteriorPower"}
     }

TEST "
R = ZZ/103[a,b,c,d]
h = matrix {{a,b},{c,d}}
assert( det h == a * d - b * c )
assert( minors(1,h) == image matrix {{a,b,c,d}} )
assert( minors(2,h) == image matrix {{a * d - b * c}} )
"

pfaffians = method(Options => { Limit => infinity })
pfaffians(ZZ,Matrix) := (j,m,options) -> (
     if j === 0 then ideal 1_(ring m)
     else if j < 0 then ideal 0_(ring m)
     else (
	  comp := PfaffiansComputation{j};
	  if not m#?comp then (
	      sendgg(
		   ggPush m,			  -- m
		   ggINT, gg j,		  -- m j
		   ggpfaffs);			  -- create computation
	      m#comp = {1, newHandle()};       -- the '1' means: not done yet.
	     );
	  if m#comp#0 =!= 0 then (
	      nsteps := if options.Limit === infinity then -1 else options.Limit;

	      sendgg(
		   ggPush m#comp#1,
		   ggPush nsteps,
		   ggcalc);
	      m#comp = {eePopInt(), m#comp#1}   -- return code: 0 means done, != 0 means more left
	      );

	  sendgg(ggPush m#comp#1,
		 ggINT, gg 0,
		 ggindex);
	  ideal getMatrix ring m
	  ))

document { quote pfaffians,
     TT "pfaffians(n,f)", " -- given a skew symmetric matrix f, produce the 
     ideal generated by its n by n pfaffians.",
     PARA,
     EXAMPLE {
	  "R=ZZ/101[a..f]",
      	  "m=genericSkewMatrix(R,a,4)",
      	  "pfaffians(2,m)",
      	  "pfaffians(4,m)",
	  },
     PARA,
     "Options:",
     MENU {
	  TO "Limit"
	  },
     SEEALSO "PfaffiansComputation"
     }

TEST ///
R=ZZ/101[a..f]
m=genericSkewMatrix(R,a,4)
assert( pfaffians(-2,m) == ideal(0_R) )
assert( pfaffians(0,m) == ideal(1_R) )
assert( pfaffians(1,m) == ideal(0_R) )
assert( pfaffians(2,m) == ideal(a,b,c,d,e,f) )
assert( pfaffians(3,m) == ideal(0_R) )
assert( pfaffians(4,m) == ideal(c*d-b*e+a*f) )
///

-----------------------------------------------------------------------------
trace = method()
trace Matrix := f -> (
     if rank source f != rank target f
     or not isFreeModule source f
     or not isFreeModule target f
     then error "expected a square matrix";
     sum(rank source f, i -> f_(i,i)))
document { quote trace,
     TT "trace f", " -- returns the trace of the matrix f.",
     PARA,
     EXAMPLE {
	  "R = ZZ/101[a..d]",
      	  "p = matrix {{a,b},{c,d}}",
      	  "trace p"
	  },
     }
-----------------------------------------------------------------------------
det Matrix := f -> (
     if rank source f != rank target f
     or not isFreeModule source f
     or not isFreeModule target f
     then error "expected a square matrix";
     (exteriorPower(numgens source f, f))_(0,0))
document { quote det,
     TT "det f", " -- returns the determinant of the matrix or table f.",
     PARA,
     EXAMPLE {
	  "R = ZZ/101[a..d]",
      	  "p = matrix {{a,b},{c,d}}",
      	  "det p"
	  },
     }

document { quote Limit,
     TT "Limit => n", " -- an optional argument for ", TO "pfaffians", "
     of for ", TO "minors", " specifying that the computation should stop 
     after n more elements are computed."
     }

fittingIdeal = method()
fittingIdeal(ZZ,Module) := (i,M) -> (
     p := presentation M;
     n := rank target p;
     if n <= i
     then ideal 1_(ring M)
     else trim minors(n-i,p))

document { quote fittingIdeal,
     TT "fittingIdeal(i,M)", " -- the i-th Fitting ideal of the module M",
     PARA,
     EXAMPLE {
	  "R = ZZ/101[x];",
      	  "k = coker vars R",
      	  "M = R^3 ++ k^5;",
      	  "fittingIdeal(3,M)",
      	  "fittingIdeal(8,M)"
	  },
     }

TEST "
R = ZZ/101[x];
k = coker vars R;
M = R^3 ++ k^5;
assert( fittingIdeal(0,M) == ideal 0_R )
assert( fittingIdeal(1,M) == ideal 0_R )
assert( fittingIdeal(2,M) == ideal 0_R )
assert( fittingIdeal(3,M) == ideal x^5 )
assert( fittingIdeal(4,M) == ideal x^4 )
assert( fittingIdeal(5,M) == ideal x^3 )
assert( fittingIdeal(6,M) == ideal x^2 )
assert( fittingIdeal(7,M) == ideal x )
assert( fittingIdeal(8,M) == ideal 1_R )
assert( fittingIdeal(9,M) == ideal 1_R )
"
