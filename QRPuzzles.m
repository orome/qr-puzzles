(* Mathematica Package *)

(* :Title: QRPuzzles *)
(* :Context: QRPuzzles` *)
(* :Author: Roy Levien *)
(* :Date: 2017-09-05 *)

(* :Package Version: 1.0.3.0 *)
(* :Mathematica Version: 11.1.1.0 *)
(* :Copyright: (c) 2015-2017 Roy Levien *)
(* :Keywords: *)
(* :Discussion: *)


(* USAGE:

    SetDirectory[NotebookDirectory[]];
    Get["QRPuzzles`"];

*)

BeginPackage["QRPuzzles`"];

Unprotect@@Names["QRPuzzles`*"];
ClearAll@@Names["QRPuzzles`*"];

(* Exported symbols added here with SymbolName::usage *)
QRPuzzles::usage = "A package for solving and generating puzzles based on small bitmaps encoding information, especially QR codes.
Inspired by the 2015 GCHQ Christmas Puzzle.";

solve::usage = "Produce a puzzle solution expressed as a table of 1s, 0s, and unknowns, given a puzzle expressed as:
   (1) 'clues' for each row and column, consisting of lists of the numbers of consecutive runs of black cells in each and
   (2) an optional 'given' partially complete state of the puzzle (expressed as a table of 0s, 1s, and unknowns).";

showTable::usage = "Show the puzzle table as a graphic, suitable for scanning or processing as a QR code, with 1s indicated in black, 0s in white, and any unknowns in gray.
Optionally indicate provided clues as row and column labels (following the format of the 2015 GCHQ puzzle specification).";

puzzleFromString::usage = "Generate a completed puzzle from a string, as a tuple consisting of a table of 1s and 0s representing the corresponding QR code as a puzzle solution, clues, and a (sufficient) table of given values.";
missing::usage = "Locate values missing from a 'partial' solution to a given puzzle 'goal' (both as tables), expressed as lists of the positions of 1s and of 0s.";

clues::usage = "Generate clues from a completed puzzle table (no unknowns), consisting of lists of the numbers of consecutive runs of black cells in each row and column.";
table::usage = "Generate a puzzle table of given dimensions from lists of positions of 1s and of 0s. Positions with unspecified values are indicated as unknown.";

cluesGCHQ::usage = "Example GCHQ clues, for demonstration purposes.";
givenGCHQ::usage = "Example GCHQ given puzzle table, for demonstration purposes.";



(* ::Package:: *)

Begin["`Private`"];


(* ******************** Public exported functions and definitions *)


(* ==================== Solution *)

(*
A puzzle is specified by (1) 'clues' for each row and column, consisting of lists of the numbers of consecutive
runs of black cells and (2) an optional 'given' partially complete state of the puzzle indicating any known values
along with the remaining unknowns.

The approach is treat the given state as an initial candidate solution, and use that and the clues to generate a new
candidate solution, which is used as a given for a subsequent iteration, unless the candidate solution has stopped
changing, in which case the search for a solution ends.

When the search ends, a fully specified puzzle will have no unknowns. The same algorithim can be used therefore
to identify cells where knows need to be provided inorder to create a fully specified puzzle (see Generation).

Each new candidate solution is generated by first filtering all possible rows allowed by the row clues against
the given's rows and expressing the resulting possible rows as a new given; then using that given to filter all
possible columns allowed by the column clues against the new given's columns and expressing the resulting possible
columns as a candidate solution.

Nearly the time here is taken up by the initialization of poss; after that, the solution is fast.
There is a possibly unnecessary refinement of sol using poss[[2]] if the preceeding poss[[1]] step has completed the
puzzle; not worth checking.

*)

solve[clues_, given_] := Module[{poss = possibles[clues], sol},
  FixedPoint[(sol = Transpose@MapThread[constraint, {poss[[1]], #}];
              sol = Transpose@MapThread[constraint, {poss[[2]], sol}])&, given]];
solve[clues_] := solve[clues, table[Length /@ clues]];


(* ==================== Display *)

(* A function to display puzzle state table, optionally labeled with clues *)
showTable[t_, {cr_, cc_}] := Grid[Join[
  Transpose@Join[ConstantArray["", {9, 9}], (Style[#, Bold]& /@ PadLeft[#, 9, ""]& /@ cc)],
  MapThread[Join, {(Style[#, Bold]& /@ PadLeft[#, 9, ""]& /@ cr), (t /. cellGraphics)}]
], gridSpecs];
showTable[t_] := Grid[t /. cellGraphics, gridSpecs];


(* ==================== Generation *)

(*

New puzzles can be generated from a full solution or from a URL.

E.g., "automated":

    {goalFromURL, cluesFromURL, givenFromUrl} = puzzleFromString["http://www.sciencegames.com"];

    showTable[goalFromURL, cluesFromURL]
    showTable[givenFromUrl, cluesFromURL]

    solutionFromURL = solve[cluesFromURL,givenFromUrl];
    showTable[solutionFromURL,cluesFromURL]
    solutionFromURL==goalFromURL
    BarcodeRecognize[(1-solutionFromURL)//Image]

or, "by hand"

    goalFromQR = 1-ImageData[BarcodeImage["http://www.subtleknife.com","QR",25]];
    cluesFromQR = clues[goalFromQR];
    solutionPartialFromQR=solve[cluesFromQR];
    givenFromQR = table[Length/@cluesFromQR, missing[goalFromQR,solutionPartialFromQR]];

    showTable[goalFromQR,cluesFromQR]
    showTable[solutionPartialFromQR, cluesFromQR]
    showTable[givenFromQR, cluesFromQR]

    solutionFromQR = solve[cluesFromQR, givenFromQR];
    showTable[solutionFromQR, cluesFromQR]
    solutionFromQR == goalFromQR
    BarcodeRecognize[(1-solutionFromQR)//Image]

*)

(* Currently only works for QR, Aztec, and Datamatrix, and sizes <= 25 *)
(* TBD - Test for valid arguments *)
puzzleFromString[url_, fmt_:"QR", size_:25] := Module[{puzGoal = 1 - ImageData[BarcodeImage[url, fmt, size]], puzClues},
  puzClues = clues[puzGoal];
  {puzGoal, puzClues, table[Length /@ puzClues, missing[puzGoal, solve[puzClues]]]}];

clues[data_] := ((Length /@ Select[Split[#], FreeQ[#, 0]&])& /@ #)& /@ {data, Transpose@data};

missing[goal_, partial_] := Intersection[Position[goal, #] , Position[partial, "-"]]& /@ {1, 0};
(*knowns[givens_] :=  Position[givens, #]& /@ {1, 0};*)

table[dims_] := ConstantArray[unknown, dims];

table[dims_, knowns_ ] := Module[{const = table[dims]},
  (const[[Sequence @@ #]] = 1)& /@ knowns[[1]]; (const[[Sequence @@ #]] = 0)& /@ knowns[[2]]; const
];

(* TBD - Automate making harder/easier through knowns reduction/increase *)
(* TBD - Generation directly from a bitmap *)


(* ==================== Example: GCHQ Problem statement *)

(* The 2015 GHCQ puzzle as an example:

    showTable[givenGCHQ, cluesGCHQ]
    solutionGCHQ = solve[cluesGCHQ, givenGCHQ];
    showTable[solutionGCHQ, cluesGCHQ]
    BarcodeRecognize[(1-solutionGCHQ)//Image]

*)

(* Define values for GCHQ 2015 puzzle *)

(* The "clues" along the sides of the puzzle *)
cluesGCHQ = {
  {{7, 3, 1, 1, 7}, {1, 1, 2, 2, 1, 1}, {1, 3, 1, 3, 1, 1, 3, 1}, {1, 3, 1, 1, 6, 1, 3, 1},
    {1, 3, 1, 5, 2, 1, 3, 1}, {1, 1, 2, 1, 1}, {7, 1, 1, 1, 1, 1, 7}, {3, 3}, {1, 2, 3, 1, 1, 3, 1, 1, 2},
    {1, 1, 3, 2, 1, 1}, {4, 1, 4, 2, 1, 2}, {1, 1, 1, 1, 1, 4, 1, 3}, {2, 1, 1, 1, 2, 5}, {3, 2, 2, 6, 3, 1},
    {1, 9, 1, 1, 2, 1}, {2, 1, 2, 2, 3, 1}, {3, 1, 1, 1, 1, 5, 1}, {1, 2, 2, 5}, {7, 1, 2, 1, 1, 1, 3},
    {1, 1, 2, 1, 2, 2, 1}, {1, 3, 1, 4, 5, 1}, {1, 3, 1, 3, 10, 2}, {1, 3, 1, 1, 6, 6},
    {1, 1, 2, 1, 1, 2}, {7, 2, 1, 2, 5}},
  {{7, 2, 1, 1, 7}, {1, 1, 2, 2, 1, 1}, {1, 3, 1, 3, 1, 3, 1, 3, 1}, {1, 3, 1, 1, 5, 1, 3, 1},
    {1, 3, 1, 1, 4, 1, 3, 1}, {1, 1, 1, 2, 1, 1}, {7, 1, 1, 1, 1, 1, 7}, {1, 1, 3}, {2, 1, 2, 1, 8, 2, 1},
    {2, 2, 1, 2, 1, 1, 1, 2}, {1, 7, 3, 2, 1}, {1, 2, 3, 1, 1, 1, 1, 1}, {4, 1, 1, 2, 6}, {3, 3, 1, 1, 1, 3, 1},
    {1, 2, 5, 2, 2}, {2, 2, 1, 1, 1, 1, 1, 2, 1}, {1, 3, 3, 2, 1, 8, 1}, {6, 2, 1}, {7, 1, 4, 1, 1, 3}, {1, 1, 1, 1, 4},
    {1, 3, 1, 3, 7, 1}, {1, 3, 1, 1, 1, 2, 1, 1, 4}, {1, 3, 1, 4, 3, 3}, {1, 1, 2, 2, 2, 6, 1}, {7, 1, 3, 2, 1, 1}}
};

(* The givens from the known values *)
givenGCHQ = table[Length /@ cluesGCHQ,
  { {{4, 4}, {4, 5}, {4, 13}, {4, 14}, {4, 22}, {9, 7}, {9, 8}, {9, 11}, {9, 15}, {9, 16}, {9, 19},
    {17, 7}, {17, 12}, {17, 17}, {17, 21}, {22, 4}, {22, 5}, {22, 10}, {22, 11}, {22, 16}, {22, 21}, {22, 22}},
    {}
  }];



(* ******************** Internal supporting functions and definitions *)


(* ==================== Solution; supporting functions *)

(* Generate a new row/column constraint from possible row/columns and an existing constraint. *)
constraint[_, const_] := const /; FreeQ[const, unknown];
constraint[poss_, const_] := Module[{constrainedPoss = Cases[poss, const /. unknown -> _]},
  Switch[#, Length[constrainedPoss], 1, 0, 0, _, unknown]& /@ (Thread[Total[#]&@constrainedPoss])];

(* TBD - This needs some fixing to be made clearer and more efficient *)
(* TBD - Can 'dim' be eliminated? *)
(* Generate all possible cells for a row/column from that row/column's clue and the dimension of the column/row *)
possible[clue_, dim_] := Module[{spec},
  spec = Module[{specN},
    specN[n_] := Switch[n, 1, #, -1, Join[{0}, #, {0}], 0, {Append[#, 0], Prepend[#, 0]}]& /@
        (Union @@ (Permutations /@ (IntegerPartitions[dim - Plus @@ clue, {Length[clue] + n}])));
    Riffle[#, clue]& /@ Union[specN[-1], Union @@ specN[0], specN[1]]];
  Flatten[{ConstantArray[0, #[[1]]], ConstantArray[1, #[[2]]]}& /@ Partition[Append[#, 0], 2]]& /@ spec];
possibles[clues_] := With[{dims = Length /@ clues},
  {possible[#, dims[[2]]]& /@ clues[[1]], possible[#, dims[[1]]]& /@ clues[[2]]}];


(* ==================== Display, etc.; supporting definitions *)

(* Some constants for use in display, etc. *)
unknown = "-";
cellGraphics = {
  1 -> Graphics[{Black, Rectangle[]}, ImageSize -> 20],
  0 -> Graphics[{White, Rectangle[]}, ImageSize -> 20],
  unknown -> Graphics[{GrayLevel[.95], Rectangle[]}, ImageSize -> 20]};
gridSpecs = Sequence[Frame -> None, Alignment -> Center, ItemSize -> {1.25, 1.25}, Spacings -> {0.2, 0.2}];

(*isDone[strip_] := FreeQ[strip, unknown];*)

End[]; (* `Private` *)

(* Protect exported symbols *)
Protect[solve, showTable, puzzleFromString, missing, clues, table];


EndPackage[];