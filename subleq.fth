\ See <https://github.com/howerj/subleq> for more information.
\ Author: Richard James Howe
\ Email: howe.r.j.89@gmail.com
defined eforth [if] ' ) <ok> ! [then] ( Turn off ok prompt )
only forth definitions hex
1 constant opt.multi      ( Add in large "pause" primitive )
1 constant opt.editor     ( Add in Text Editor )
1 constant opt.info       ( Add info printing function )
0 constant opt.generate-c ( Generate C code )
0 constant opt.better-see ( Replace 'see' with better version )
1 constant opt.control    ( Add in more control structures )
0 constant opt.allocate   ( Add in "allocate"/"free" )
0 constant opt.float      ( Add in floating point code )
0 constant opt.glossary   ( Add in "glossary" word )
0 constant opt.sm-vm-err  ( Smaller VM error message )
0 constant opt.optimize   ( Enable extra optimization )
1 constant opt.divmod     ( Use "opDivMod" primitive )
1 constant opt.self       ( Enable self-interpreter )
: sys.echo-off 1 or ; ( bit #1 = turn echoing chars off )
: sys.cksum    2 or ; ( bit #2 = turn checksumming on )
: sys.info     4 or ; ( bit #3 = print info msg on startup )
: sys.eof      8 or ; ( bit #4 = die if received EOF )
: sys.warnv  $10 or ; ( bit #5 = warn if virtualized )
0 ( sys.cksum ) ( sys.eof ) ( sys.echo-off ) sys.warnv constant opt.sys
defined (order) 0= [if]
: (order) ( w wid*n n -- wid*n w n )
  dup if
    1- swap >r recurse over r@ xor
    if 1+ r> -rot exit then rdrop
  then ;
: -order get-order (order) nip set-order ; ( wid -- )
: +order dup >r -order get-order r> swap 1+ set-order ;
[then]
defined [unless] 0= [if]
: [unless] 0= postpone [if] ; immediate
[then]
defined eforth [if]
  : wordlist here cell allot 0 over ! ; ( -- wid : alloc wid )
[then]
wordlist constant meta.1        ( meta-compiler word set )
wordlist constant target.1      ( target eForth word set )
wordlist constant assembler.1   ( assembler word set )
wordlist constant target.only.1 ( target only word set )
defined eforth [if] system +order [then]
meta.1 +order definitions
   2 constant =cell   \ Target cell size
4000 constant size    \ Size of image working area
 100 constant =buf    \ Size of text input buffers in target
 100 constant =stksz  \ Size of return and variable stacks
FC00 constant =thread \ Initial start of thread area
0008 constant =bksp   \ Backspace character value
000A constant =lf     \ Line feed character value
000D constant =cr     \ Carriage Return character value
007F constant =del    \ Delete character
create tflash tflash size cells allot size erase
variable tzreg 0 tzreg !
variable tareg 1 tareg !
variable tdp 0 tdp ! ( target dictionary pointer )
variable tlast 0 tlast ! ( last defined target word pointer )
variable tlocal 0 tlocal ! ( local variable allocator )
variable voc-last 0 voc-last ! ( last defined in any vocab )
: :m meta.1 +order definitions : ; ( --, "name" )
: ;m postpone ; ; immediate ( -- )
:m tcell 2 ;m ( -- 2 : bytes in a target cell )
:m there tdp @ ;m ( -- a : target dictionary pointer value )
:m tc! tflash + c! ;m ( c a -- : target write char )
:m tc@ tflash + c@ ;m ( a -- c : target get char )
:m t! over FF and over tc! swap 8 rshift swap 1+ tc! ;m
:m t@ dup tc@ swap 1+ tc@ 8 lshift or ;m ( a -- u : target @ )
:m taligned dup 1 and + ;m ( u -- u : align target pointer )
:m talign there 1 and tdp +! ;m ( -- : align target dic. ptr. )
:m tc, there tc! 1 tdp +! ;m ( c -- : write char to targ. dic.)
:m t, there t! 2 tdp +! ;m ( u -- : write cell to target dic. )
:m tallot tdp +! ;m ( u -- : allocate bytes in target dic. )
:m mdrop drop ;m ( u -- : always call drop )
:m mswap swap ;m ( u -- : always call swap )
:m mdecimal decimal ;m ( -- : always call decimal )
:m mhex hex ;m ( -- : always call hex )
:m (field) 2dup + -rot ;m ( pos n -- pos+n pos n )
defined eforth [if]
  :m tpack dup tc, for aft count tc, then next drop ;m
  :m parse-word bl word ?nul count ;m ( -- a u )
  :m limit ;m ( u -- u16 : not needed on 16-bit systems )
[else]
  :m tpack talign dup tc, 0 ?do count tc, loop drop ;m
  :m limit FFFF and ;m ( u -- u16 : limit variable to 16 bits )
[then]
:m $literal talign [char] " word count tpack talign ;m
defined eforth [if]
:m #dec s>d if [char] - emit then (.) ;m ( n16 -- )
[else]
  :m #dec dup 8000 u>= if negate limit -1 >r else 0 >r then
     0 <# #s r> sign #> type ;m ( n16 -- )
[then]
opt.generate-c [if]
  :m msep 2C emit ;m ( -- : emit "," as separator )
[else]
  :m msep A emit ;m  ( -- : emit space as separator )
[then]
:m mdump taligned ( a u -- )
  begin ?dup
  while swap dup @ limit #dec msep tcell + swap tcell -
  repeat drop ;m
:m save-target decimal tflash there mdump ;m ( -- )
:m .end only forth definitions decimal ;m ( -- )
:m atlast tlast @ ;m ( -- a : meta-comp last defined word )
:m local? tlocal @ ;m ( -- u : meta-comp local offset )
:m lallot >r tlocal @ r> + tlocal ! ;m ( u -- allot in target )
:m tuser ( --, "name", Created-Word: -- u )
  get-current >r meta.1 set-current create r>
  set-current tlocal @ =cell lallot , does> @ ;m
:m tvar get-current >r ( --, "name", Created-Word: -- a )
     meta.1 set-current create
   r> set-current there , t, does> @ ;m
:m label: get-current >r ( --, "name", Created-Word: -- a )
     meta.1 set-current create
   r> set-current there ,    does> @ ;m
:m tdown =cell negate and ;m ( a -- a : align down )
:m tnfa =cell + ;m ( pwd -- nfa : move to name field address )
:m tcfa tnfa dup c@ 1F and + =cell + tdown ;m ( pwd -- cfa )
:m compile-only voc-last @ tnfa t@ 20 or voc-last @ tnfa t! ;m
:m immediate   voc-last @ tnfa t@ 40 or voc-last @ tnfa t! ;m
:m half dup 1 and abort" unaligned" 2/ ;m ( a -- a : meta 2/ )
:m double 2* ;m ( a -- a : meta-comp 2* )
defined eforth [if]
:m (') bl word find ?found cfa ;m
:m t' (') >body @ ;m ( --, "name" )
:m to' target.only.1 +order (') >body @ target.only.1 -order ;m
[else]
:m t' ' >body @ ;m ( --, "name" )
:m to' target.only.1 +order ' >body @ target.only.1 -order ;m
[then]
:m tcompile to' half t, ;m
:m >tbody =cell + ;m
:m tcksum taligned dup C0DE - FFFF and >r
   begin ?dup
   while swap dup t@ r> + FFFF and >r =cell + swap =cell -
   repeat drop r> ;m ( a u -- u : compute a checksum )
:m mkck dup there swap - tcksum ;m ( -- u : checksum of image )
:m postpone ( --, "name" )
   target.only.1 +order t' target.only.1 -order 2/ t, ;m
:m thead talign there tlast @ t, dup tlast ! voc-last !
   parse-word talign tpack talign ;m ( --, "name" )
:m header >in @ thead >in ! ;m ( --, "name" )
:m :ht ( "name" -- : forth routine, no header )
  get-current >r target.1 set-current create
  r> set-current CAFE talign there ,
  does> @ 2/ t, ;m
:m :t header :ht ;m ( "name" -- : forth routine )
:m :to ( "name" -- : forth, target only routine )
  header
  get-current >r
    target.only.1 set-current create
  r> set-current
  CAFE talign there ,
  does> @ 2/ t, ;m
:m :a ( "name" -- : assembly routine, no header )
  1234 target.1 +order definitions
  create talign there , assembler.1 +order does> @ 2/ t, ;m
:m (fall-through); 1234 <>
   if abort" unstructured" then assembler.1 -order ;m
:m (a); (fall-through); ;m
defined eforth [if] system -order [then]
:m Z tzreg @ t, ;m ( -- : Address 0 must contain 0 )
:m A, Z ;m ( -- : Synonym for 'Z', temporary location )
:m V, tareg @ t, ;m ( -- : Address 1 also contains 0, tmp loc )
:m NADDR there 2/ 1+ t, ;m ( --, jump to next cell )
:m HALT Z Z -1 t, ;m ( --, Halt but do not catch fire )
:m JMP 2/ Z Z t, ;m ( a --, Jump to location )
:m ADD swap 2/ t, Z NADDR Z 2/ t, NADDR Z Z NADDR ;m
:m SUB swap 2/ t, 2/ t, NADDR ;m ( a a -- : subtract )
:m NOOP Z Z NADDR ;m ( -- : No operation )
:m ZERO dup 2/ t, 2/ t, NADDR ;m ( a -- : zero a location )
:m PUT 2/ t, -1 t, NADDR ;m ( a -- : put a byte )
:m GET 2/ -1 t, t, NADDR ;m ( a -- : get a byte )
:m MOV 2/ >r r@ dup t, t, NADDR 2/ t, Z  NADDR r> Z  t, NADDR
   Z Z NADDR ;m
:m iJMP there 2/ E + 2* MOV Z Z NADDR ;m ( a -- )
:m iADD ( a a -- : indirect add )
   2/ t, A, NADDR
   2/ t, V, NADDR
   there 2/ 7 + dup dup t, t, NADDR
   A,   t, NADDR
   V, 0 t, NADDR
   A, A, NADDR
   V, V, NADDR ;m
:m iSUB ( a a -- : indirect sub )
   2/ t, A, NADDR
   2/ >r
   there 2/ 7 + dup dup t, t, NADDR
   A,   t, NADDR
   r> t, 0 t, NADDR
   A, A, NADDR ;m
:m iSTORE ( a a -- : Indirect Store )
  2/ t, A, NADDR
  there 2/ 3 4 * + dup t, t, NADDR
  there 2/ $A + dup t, t, NADDR
  A, there 2/ 5 + t, NADDR
  A, there 2/ 3 + t, NADDR
  0 t, 0 t, NADDR
  2/ t, V, NADDR
  there 2/ 7 + dup dup t, t, NADDR
  A,   t, NADDR
  V, 0 t, NADDR
  A, A, NADDR
  V, V, NADDR
  ;m
:m iLOAD there 2/ 3 4 * 3 + + 2* MOV 0 swap MOV ;m ( a a -- )
assembler.1 +order definitions
: begin talign there ; ( -- a )
: again JMP ; ( a -- )
: mark there 0 t, ; ( -- a : create hole in dictionary )
: if talign ( a -- a : N.B. "if" does not work for $8000 )
   2/ dup t, Z there 2/ 4 + dup t, Z Z 6 + t, Z Z NADDR Z t,
   mark ;
: until 2/ dup t, Z there 2/ 4 + dup t, Z Z 6 + t,
   Z Z NADDR Z t, 2/ t, ; ( a -- a )
: else talign Z Z mark swap there 2/ swap t! ; ( a -- a )
: +if talign Z 2/ t, mark ; ( a -- a )
: -if talign
   2/ t, Z there 2/ 4 + t, Z Z there 2/ 4 + t, Z Z mark ;
: then begin 2/ swap t! ; ( a -- )
: while if swap ; ( a a -- a a )
: repeat JMP then ; ( a a -- )
assembler.1 -order
meta.1 +order definitions
  0 t, 0 t,        \ both locations must be zero
label: entry       \ used to set entry point in next cell
  -1 t,            \ system entry point, set later
opt.sys tvar {options} \ bit #1=echo off, #2 = checksum on,
                   \ #4=info, #8=die on EOF
  0 tvar primitive \ any address lower must be a VM primitive
  =stksz half tvar stacksz \ must contain $80
 -1 tvar neg1      \ must contain -1
  1 tvar one       \ must contain  1
$10 tvar bwidth    \ must contain 16
$40 tvar mwidth    \ maximum machine width
  0 tvar r0        \ working pointer 1 (register r0)
  0 tvar r1        \ register 1
  0 tvar r2        \ register 2
  0 tvar r3        \ register 3
  0 tvar r4        \ register 4
opt.self [if]
  0 tvar {virtual} \ are we virtualized?
  0 tvar {self}    \ location of the self interpreter
  0 tvar {pc}      \ Emulated SUBLEQ Machine program counter
$10 tvar {width}   \ set by size detection routines
[then]
  0 tvar h         \ dictionary pointer
  =thread half tvar {up} \ Current task addr. (Half size)
  0 tvar check     \ used for system checksum
  0 tvar {context} E tallot \ vocabulary context
  0 tvar {current}  \ vocabulary to add new definitions to
  0 tvar {forth-wordlist} \ forth word list (main vocabulary)
  0 tvar {editor}   \ editor vocabulary
  0 tvar {root-voc} \ absolute minimum vocabulary
  0 tvar {system}   \ system functions vocabulary
  0 tvar {boot}     \ entry point of VM program, set later on
  0 tvar {quit}     \ Execution token called after init
  0 tvar {last}     \ last defined word
  0 tvar {cycles}   \ number of times we have switched tasks
  1 tvar {single}   \ is multi processing off? +ve = off
  0 tvar {user}     \ Number of locals assigned
  \ Thread variables, not all of which are user variables
  0 tvar ip         \ instruction pointer
  0 tvar tos        \ top of stack
  =thread =stksz        + half dup tvar {rp0} tvar {rp}
  =thread =stksz double + half dup tvar {sp0} tvar {sp}
  200 constant =tib \ Start of terminal input buffer
  380 constant =num \ Start of numeric input buffer
  tuser {next-task} \ next task in task list
  tuser {ip-save}   \ saved instruction pointer
  tuser {tos-save}  \ saved top of variable stack
  tuser {rp-save}   \ saved return stack pointer
  tuser {sp-save}   \ saved variable stack pointer
  tuser {handler}   \ throw/catch handler
  tuser {sender}    \ multitasking; msg. send, 0 = no message
  tuser {message}   \ multitasking; the message itself
  tuser {id}        \ executing from block or terminal?
  tuser {precision} \ floating point precision (if FP on)
:m INC 2/ neg1 2/ t, t, NADDR ;m ( b -- )
:m DEC 2/ one  2/ t, t, NADDR ;m ( b -- )
:m ONE! dup ZERO INC ; ( a -- : set address to '1' )
:m NG1! dup ZERO DEC ; ( a -- : set address to '-1' )
:m ++sp {sp} DEC ;m ( -- : grow variable stack )
:m --sp {sp} INC ;m ( -- : shrink variable stack )
:m --rp {rp} DEC ;m ( -- : shrink return stack )
:m ++rp {rp} INC ;m ( -- : grow return stack )
opt.optimize [if] ( optimizations on )
  :m a-optim 2/ >r there =cell - r> swap t! ;m ( a -- )
[else]
  :m a-optim drop ;m ( a -- : optimization off )
[then]
opt.sm-vm-err [if]
( Smaller, more cryptic, error message string "Error" )
45 tvar err-str
  72 t, 72 t, 6F t, 72 t, 0D t, 0A t, -1 t,
[else]
( Error message string "Error: Not a 16-bit SUBLEQ VM" )
45 tvar err-str
  72 t, 72 t, 6F t, 72 t, 3A t, 20 t, 4E t,
  6F t, 74 t, 20 t, 61 t, 20 t, 31 t, 36 t, 2D t,
  62 t, 69 t, 74 t, 20 t, 53 t, 55 t, 42 t, 4C t,
  45 t, 51 t, 20 t, 56 t, 4D t, 0D t, 0A t, -1 t,
[then]
err-str 2/ tvar err-str-addr
assembler.1 +order
label: die
   err-str-addr r0 MOV ( load string address )
   label: die.loop
     r1 r0 iLOAD       ( load character )
     r0 INC            ( increment to next cell )
     r1 +if 
       r1 PUT       ( output single byte )
       die.loop JMP ( sentinel is a negative val )
     then 
   ( fall-through )
:a bye ( -- : first VM word, "bye", or halt the Forth system )
   HALT (a); ( ...like tears in rain. Time to die. )
assembler.1 +order
label: start         \ System Entry Point
  start 2/ entry t!  \ Set the system entry point
  r0 ONE!                          \ r0 = shift bit loop count
  r1 ONE!                          \ r1 = number of bits
label: chk16
  r0 r0 ADD                        \ r0 = r0 * 2
  r1 INC                           \ r1++
  r1 r2 MOV                        \ r2 = r1
  mwidth r2 SUB r2 +if die JMP then \ check length < max width
  r0 +if chk16 JMP then            \ check if still positive
opt.self [if] \ if width > 16, jump to 16-bit emulator
  r1 r2 MOV
  r1 {width} MOV \ Save actual machine width
  bwidth r2 SUB r2 +if {self} iJMP then
[then]
  bwidth r1 SUB r1 if die JMP then \ r1 - bwidth should be 0
opt.self [if] ( self JMP ) there 2/ {pc} t!  [then]
  {sp0} {sp} MOV     \ Setup initial variable stack
  {rp0} {rp} MOV     \ Setup initial return stack
  {boot} ip MOV      \ Get the first instruction to execute
  ( fall-through )
label: vm ( Forth Inner Interpreter )
  r0 ip iLOAD         \ Get instruction to execute from IP
  ip INC              \ IP now points to next instruction!
  primitive r1 MOV    \ Copy as SUB is destructive
  r0 r1 SUB           \ Check if it is a primitive
  r1 +if r0 iJMP then \ Jump straight to VM functions if it is
  ++rp                \ If it wasn't a VM instruction, inc {rp}
  ip {rp} iSTORE      \ and store ip to return stack
  r0 ip MOV vm a-optim \ "r0" holds our next instruction
  vm JMP              \ Ad infinitum...
:m ;a (fall-through); vm a-optim vm JMP ;m
opt.self [if]
0 tvar {zreg} {zreg} 2/ tzreg !
0 tvar {areg} {areg} 2/ tareg !
 0000 tvar {a}     ( Emulated 'a' operand )
 0000 tvar {b}     ( Emulated 'b' operand )
 0000 tvar {v}     ( Temporary register 'v' )
-0010 tvar {count} ( Top bit count, modified later )
label: self
self 2/ {self} t!
  {virtual} NG1!
  {width} {count} ADD
label: self-loop
  {pc} {v} MOV \ Copy {pc} for next instruction
  neg1 2/ t, {v} 2/ t, -1 t, \ Conditionally halt on '{c}'
  {a} {pc} iLOAD {pc} INC
  {b} {pc} iLOAD {pc} INC
  {a} {v} MOV {v} INC {v} +if ( Input byte? )
    {b} {v} MOV {v} INC {v} +if ( Output byte? )
      ( Neither Input nor Output, must be normal instruction )
      \ This section performs "m[b] = m[b] - m[a]" and loads
      \ the result back into "{a}". A custom "iSUB" routine
      \ might speed things up here, one that stored the result
      \ in "{b}" but also kept a copy in "{a}".
      {a} {a} iLOAD  \ a = m[a]
      {a} {b} iSUB   \ m[b] = m[b] - a
      {a} {b} iLOAD  \ a = m[b]
      \ This section prepares "{a}" for the next "+if", it
      \ shifts the 16-bit into the top place depending on the
      \ machine width. The bits lower than the 16-bit do not
      \ matter unless they are all zero, in which case this
      \ shifting has no effect anyway.
      {count} {v} MOV
      label: self.bit
        {a} {a} ADD {v} DEC 
      {v} +if self.bit JMP then
      {a} +if \ !(v == 0 || v & 0x8000)
        {pc} INC
        self-loop JMP
      then
      {pc} {pc} iLOAD \ pc = m[c]
      self-loop JMP
    then ( Output byte from m[a] )
    {a} {a} iLOAD
    {a} PUT
    {pc} INC
    self-loop JMP
  then ( Input byte and store in m[b] )
  {a} GET
  {a} {b} iSTORE
  {pc} INC
  self-loop JMP ( And do it again... )
  0 tzreg !
  1 tareg !
[then]
assembler.1 -order
:a opSwap tos r0 MOV tos {sp} iLOAD r0 {sp} iSTORE ;a
:a opDup ++sp tos {sp} iSTORE ;a ( n -- n n )
:a opFromR ++sp tos {sp} iSTORE tos {rp} iLOAD --rp ;a
:a opToR ++rp tos {rp} iSTORE (fall-through); ( !!! )
:a opDrop tos {sp} iLOAD --sp ;a ( n -- )
:a [@] tos tos iLOAD ;a ( a -- a : load SUBLEQ address )
:a [!] r0 {sp} iLOAD r0 tos iSTORE --sp t' opDrop JMP (a);
:a out! ( u a -- : output, unlike input, needs special casing )
   tos r0 MOV
   tos {sp} iLOAD
   --sp
   r0 there $D 2* + MOV
   tos 2/ t, 0 t, NADDR
   t' opDrop JMP (a);
:a opExit ip {rp} iLOAD (fall-through); ( !!! ) ( R: a -- )
:a rdrop --rp ;a ( R: u -- )
:a opIpInc ip INC ;a ( -- : increment instruction pointer )
:a opJumpZ ( u -- : Conditional jump on zero )
  tos r0 MOV
  tos {sp} iLOAD --sp
  r0 if t' opIpInc JMP then r0 DEC r0 +if t' opIpInc JMP then
  (fall-through); ( !!! )
:a opJump ip ip iLOAD ;a ( -- : Unconditional jump )
:a opNext r0 {rp} iLOAD ( R: n -- | n-1 )
   r0 +if r0 DEC r0 {rp} iSTORE t' opJump JMP then
   --rp t' opIpInc JMP (a);
:a op0= ( n -- f : not equal to zero )
 ( does not work: "tos if tos ZERO else tos NG1! then vm JMP" )
 tos if ( assembly 'if' does not work for entire range )
   tos ZERO
 else ( deal with incorrect results )
   tos DEC
   tos +if tos ZERO else tos NG1! then
 then ;a
:a leq0 ( n -- 0|1 : less than or equal to zero )
  Z tos 2/ t, there 2/ 4 + t,
  tos 2/ dup t, t, vm 2/ t,
  tos ONE! ;a
:a - tos {sp} iSUB t' opDrop JMP (a); ( n n -- n )
:a + tos {sp} iADD t' opDrop JMP (a); ( n n -- n )
:a shift ( u n -- u : right shift 'u' by 'n' places )
  bwidth r0 MOV       \ load machine bit width
  tos r0 SUB          \ adjust tos by machine width
  tos {sp} iLOAD --sp \ pop value to shift
  r1 ZERO             \ zero result register
  label: shift.loop
    r1 r1 ADD \ double r1, equivalent to left shift by one
    \ work out what bit to shift into r1
    tos +if else
      tos r2 MOV r2 INC r2 +if else r1 INC then then
    tos tos ADD \ double tos, equivalent to left shift by one
    r0 DEC \ decrement loop counter
  r0 +if shift.loop JMP then 
  r1 tos MOV ;a \ move result back into tos
:a opMux ( u1 u2 u3 -- u : bitwise multiplexor function )
  \ tos contains multiplexor value
  bwidth r0 MOV \ load loop counter initial value [16]
  r1 ZERO       \ zero results register
  r3 {sp} iLOAD --sp \ pop first input
  r4 {sp} iLOAD --sp \ pop second input
  
  label: opMux.loop
    r1 r1 ADD \ shift results register
    \ determine topmost bit of 'tos', place result in 'r2'
    \ this is used to select whether to use r3 or r4
    tos +if label: opMux.r3 r3 r2 MOV else
      tos r2 MOV
      r2 INC r2 +if
        opMux.r3 JMP ( space saving ) else
        r4 r2 MOV then then
    \ determine whether we should add 0/1 into result
    r2 +if else r2 INC r2 +if else r1 INC then then
    tos tos ADD \ shift tos
    r3 r3 ADD \ shift r3
    r4 r4 ADD \ shift r4
    r0 DEC \ decrement loop counter
    r0 +if opMux.loop JMP then
  r1 tos MOV ;a \ move r1 to tos, returning our result
opt.divmod [if]
:a opDivMod ( u1 u2 -- u1 u2 )
  r0 {sp} iLOAD
  r1 ZERO ( zero quotient )
  label: divStep
    r1 INC     ( increment quotient )
    tos r0 SUB ( repeated subtraction )
    r0 -if 
      tos r0 ADD     ( correct remainder )
      r1 DEC         ( correct quotient )
      r1 tos MOV     ( store results back to tos )
      r0 {sp} iSTORE ( ...and stack )
      vm JMP         ( finish... )
    then
  divStep JMP ( perform another division step )
  (a);
[then]
opt.multi [if]
:a pause ( -- : pause and switch task )
  \ "{single}" must be positive and not zero to 
  \ turn off "pause", this is to save space as "+if" can be
  \ used.
  {single} +if vm JMP then \ Do nothing if single-threaded mode
  r0 {up} iLOAD \ load next task pointer from user storage
  \ "+if" saves space, "r0" should never be negative anyway as
  \ this would mean that the thread was above the 32678 mark
  \ and thus in an area where "@" and "!" would not work (only
  \ "[@]" and "[!]".
  r0 +if 
    {cycles} INC        \ increment "pause" count
    {up} r1 MOV  r1 INC \ load TASK pointer, skip next task loc
      ip r1 iSTORE r1 INC \ save registers to current task
     tos r1 iSTORE r1 INC \ only a few need to be saved
    {rp} r1 iSTORE r1 INC
    {sp} r1 iSTORE
      r0 {rp0} MOV stacksz {rp0} ADD \ change {rp0} to new loc
   {rp0} {sp0} MOV stacksz {sp0} ADD \ same but for {sp0}
      r0 {up} MOV r0 INC \ set next task
      ip r0 iLOAD r0 INC \ reverse of save registers
     tos r0 iLOAD r0 INC
    {rp} r0 iLOAD r0 INC
    {sp} r0 iLOAD        \ we're all golden
  then ;a
[else]
:m pause ;m ( -- [disabled] )
[then]
there 2/ primitive t! ( set 'primitive', needed for VM )
:m munorder target.only.1 -order talign ;m
:m (;t)
   CAFE <> if abort" Unstructured" then
   munorder ;m
:m ;t (;t) opExit ;m
:m :s tlast @ {system} t@ tlast ! F00D :t drop 0 ;m
:m :so  tlast @ {system} t@ tlast ! F00D :to drop 0 ;m
:m ;s drop CAFE ;t F00D <> if abort" unstructured" then
  tlast @ {system} t! tlast ! ;m
:m :r tlast @ {root-voc} t@ tlast ! BEEF :t drop 0 ;m
:m ;r drop CAFE ;t BEEF <> if abort" unstructured" then
  tlast @ {root-voc} t! tlast ! ;m
:m :e tlast @ {editor} t@ tlast ! DEAD :t drop 0 ;m
:m ;e drop CAFE ;t DEAD <> if abort" unstructured" then
  tlast @ {editor} t! tlast ! ;m
:m system[ tlast @ {system} t@ tlast ! BABE ;m
:m ]system BABE <> if abort" unstructured" then
   tlast @ {system} t! tlast ! ;m
:m root[ tlast @ {root-voc} t@ tlast ! D00D ;m
:m ]root D00D <> if abort" unstructured" then
   tlast @ {root-voc} t! tlast ! ;m
:m : :t ;m ( -- ???, "name" : start cross-compilation )
:m ; ;t ;m ( ??? -- : end cross-compilation of a target word )
:m begin talign there ;m ( -- a : meta 'begin' )
:m until talign opJumpZ 2/ t, ;m  ( a -- : meta 'until' )
:m again talign opJump  2/ t, ;m ( a -- : meta 'again' )
:m if opJumpZ there 0 t, ;m ( -- a : meta 'if' )
:m tmark opJump there 0 t, ;m ( -- a : meta mark location )
:m then there 2/ swap t! ;m ( a -- : meta 'then' )
:m else tmark swap then ;m ( a -- a : meta 'else' )
:m while if ;m ( -- a : meta 'while' )
:m repeat swap again then ;m ( a a -- : meta 'repeat' )
:m aft drop tmark begin swap ;m ( a -- a a : meta 'aft' )
:m next talign opNext 2/ t, ;m ( a -- : meta 'next' )
:m for opToR begin ;m ( -- a : meta 'for )
:m =jump   [ t' opJump  half ] literal ;m ( -- a )
:m =jumpz  [ t' opJumpZ half ] literal ;m ( -- a )
:m =unnest [ t' opExit  half ] literal ;m ( -- a )
:m =>r     [ t' opToR   half ] literal ;m ( -- a )
:m =next   [ t' opNext  half ] literal ;m ( -- a )
:m dup opDup ;m ( -- : compile opDup into the dictionary )
:m drop opDrop ;m ( -- : compile opDrop into the dictionary )
:m swap opSwap ;m ( -- : compile opSwap into the dictionary )
:m >r opToR ;m ( -- : compile opTorR into the dictionary )
:m r> opFromR ;m ( -- : compile opFromR into the dictionary )
:m 0= op0= ;m ( -- : compile op0= into the dictionary )
:m mux opMux ;m ( -- : compile opMux into the dictionary )
:m exit opExit ;m ( -- : compile opExit into the dictionary )
:m rshift shift ;m ( -- : compile shift into the dictionary )
:to + + ; ( n n -- n : addition )
:to - - ; ( n1 n2 -- n : subtract n2 from n1 )
:to bye bye ; ( -- : halt the system )
:to dup dup ; ( n -- n n : duplicate top of variable stack )
:to drop opDrop ; ( n -- : drop top of variable stack )
:to swap opSwap ; ( x y -- y x : swap two variables on stack )
:to rshift shift ; ( u n -- u : logical right shift by "n" )
:so [@] [@] ;s ( vma -- : fetch -VM Address- )
:so [!] [!] ;s ( u vma -- : store to -VM Address- )
:to 0= op0= ; ( n -- f : equal to zero )
:so leq0 leq0 ;s ( n -- 0|1 : less than or equal to zero )
:so mux opMux ;s ( u1 u2 sel -- u : bitwise multiplex op. )
:so pause pause ;s ( -- : pause current task, task switch )
: 2* dup + ; ( u -- u : multiply by two )
:s (const) r> [@] ;s compile-only ( R: a --, -- u )
:m constant :t mdrop (const) t, munorder  ;m
system[
 0 constant #0  ( --  0 : push the number zero onto the stack )
 1 constant #1  ( --  1 : push one onto the stack )
-1 constant #-1 ( -- -1 : push negative one onto the stack )
 2 constant #2  ( --  2 : push two onto the stack )
-2 constant -cell  ( -- -2 : push negative two onto the stack )
]system
: 1+ #1 + ; ( n -- n : increment value in cell )
: 1- #1 - ; ( n -- n : decrement value in cell )
:s (push) r> dup [@] swap 1+ >r ;s ( -- n : inline push value )
:m lit (push) t, ;m ( n -- : compile a literal )
:m literal lit ;m ( n -- : synonym for "lit" )
:m ] ;m ( -- : meta-compiler version of "]", do nothing )
:m [ ;m ( -- : meta-compiler version of "[", do nothing )
:s (up) r> dup [@] [ {up} half ] literal [@] 2* + swap 1+ >r ;s
  compile-only ( -- n : user variable implementation word )
:s (var) r> 2* ;s compile-only ( R: a --, -- a )
:s (user) r> [@] [ {up} half ] literal [@] 2* + ;s compile-only
  ( R: a --, -- u )
:m up (up) t, ;m ( n -- : compile user variable )
:m [char] char (push) t, ;m ( --, "name" : compile char )
:m char   char (push) t, ;m ( --, "name" : compile char )
:m variable :t mdrop (var) 0 t, munorder ;m ( --, "name": var )
:m user :t mdrop (user) local? =cell lallot t, munorder ;m
:to ) ; immediate ( -- : NOP, terminate comment )
: over swap dup >r swap r> ; ( n1 n2 -- n1 n2 n1 )
: invert #-1 swap - ;             ( u -- u : bitwise invert )
: xor >r dup invert swap r> mux ; ( u u -- u : bitwise xor )
: or over mux ;                   ( u u -- u : bitwise or )
: and #0 swap mux ;               ( u u -- u : bitwise and )
: 2/ #1 rshift ; ( u -- u : divide by two )
: @ 2/ [@] ; ( a -- u : fetch a cell to a memory location )
: ! 2/ [!] ; ( u a -- : write a cell to a memory location )
:s @+ dup @ ;s ( a -- a u : non-destructive load )
user <ok> ( -- a : okay prompt xt loc. )
system[
  user <emit>    ( -- a : emit xt loc. )
  user <key>     ( -- a : key xt loc. )
  user <echo>    ( -- a : echo xt loc. )
  user <literal> ( -- a : literal xt loc. )
  user <tap>     ( -- a : tap xt loc. )
  user <expect>  ( -- a : expect xt loc. )
  user <error>   ( -- a : <error> xt container. )
]system
:s <boot> [ {boot} ] literal ;s ( -- a : cold xt loc. )
:s <quit> [ {quit} ] literal ;s ( -- a : quit xt loc. )
: current ( -- a : get current vocabulary )
  [ {current} ] literal ;
: root-voc ( -- a : get root vocabulary )
  [ {root-voc} ] literal ;
: this [ 0 ] up ; ( -- a : address of task thread memory )
: pad this [ 3C0 ] literal + ; ( -- a : index into pad area )
8 constant #vocs ( -- u : number of vocabularies )
: context [ {context} ] literal ; ( -- a )
variable blk ( -- a : loaded block )
variable scr ( -- a : latest listed block )
2F t' scr >tbody t! ( Set default block to list, an empty one )
user base  ( -- a : push the radix for numeric I/O )
user dpl   ( -- a : decimal point variable )
user hld   ( -- a : index to hold space for num. I/O)
user state ( -- f : interpreter state )
user >in   ( -- a : input buffer position var )
user span  ( -- a : number of chars saved by expect )
$20 constant bl ( -- 32 : push space character )
system[
       h constant h?  ( -- a : push the location of dict. ptr )
{cycles} constant cycles ( -- a : number of "cycles" ran for )
    {sp} constant sp     ( -- a : address of v.stk ptr. )
  {user} constant user?  ( -- a : address of user alloc var )
         variable calibration 1400 t' calibration >tbody t!
]system
:s radix base @ ;s ( -- u : retrieve base )
: here h? @ ;      ( -- u : push the dictionary pointer )
: sp@ sp @ 1+ ; ( -- a : Fetch variable stack pointer )
: sp! 1- [ {sp} half ] literal [!] #1 drop ;
: rp@ [ {rp} half ] literal [@] 1- ; compile-only
: rp! r> swap [ {rp} half ] literal [!] >r ; compile-only
: hex [ $10 ] literal base ! ; ( -- : hexadecimal base )
: decimal [ $A ] literal base ! ; ( -- : decimal base )
:to ] #-1 state ! ; ( -- : return to compile mode )
:to [  #0 state ! ; immediate ( -- : initiate command mode )
: nip swap drop ;   ( x y -- y : remove second item on stack )
: tuck swap over ;  ( x y -- y x y : save item for rainy day )
: ?dup dup if dup then ; ( x -- x x | 0 : conditional dup )
: r@ r> r> tuck >r >r ; compile-only ( R: n -- n, -- n )
: rot >r swap r> swap ; ( x y z -- y z x : "rotate" stack )
: -rot rot rot ; ( x y z -- z x y : "rotate" stack backwards )
: 2drop drop drop ; ( x x -- : drop it like it is hot )
: 2dup  over over ; ( x y -- x y x y )
:s shed rot drop ;s ( x y z -- y z : drop third stack item )
: = - 0= ;     ( u1 u2 -- f : equality )
: <> = 0= ;    ( u1 u2 -- f : inequality )
: 0> leq0 0= ; ( n -- f : greater than zero )
: 0<> 0= 0= ;  ( n -- f : not equal to zero )
: 0<= 0> 0= ;  ( n -- f : less than or equal to zero )
: < ( n1 n2 -- f : less than, is n1 less than n2 )
   2dup leq0 swap leq0 if
     if
       2dup 1+ leq0 swap 1+ leq0
       if drop else if 2drop #0 exit then then
     else 2drop #-1 exit then \ a0 && !b0
   else
     if 2drop #0 exit then \ !a0 && b0
   then
   2dup - leq0 if
     swap 1+ swap - leq0 if #-1 exit then
     #0 exit
   then
   2drop #0 ;
: > swap < ;   ( n1 n2 -- f : signed greater than )
: 0< #0 < ;   ( n -- f : less than zero )
: 0>= 0< 0= ; ( n1 n2 -- f : greater or equal to zero )
: >= < 0= ;   ( n1 n2 -- f : greater than or equal to )
: <= > 0= ;   ( n1 n2 -- f : less than or equal to )
: u< 2dup 0>= swap 0>= <> >r < r> <> ; ( u1 u2 -- f )
: u> swap u< ; ( u1 u2 -- f : unsigned greater than )
: u>= u< 0= ; ( u1 u2 -- f : unsigned greater or equal to )
: u<= u> 0= ; ( u1 u2 -- f : unsigned less than or equal to )
: within over - >r - r> u< ; ( u lo hi -- f )
: negate 1- invert ; ( n -- n : twos compliment negation )
: s>d dup 0< ; ( n -- d : signed to double width cell )
: abs s>d if negate then ; ( n -- u : absolute value )
2 constant cell ( -- u : push bytes in cells to stack )
: cell+ cell + ; ( a -- a : increment address by cell width )
: cells 2* ;     ( u -- u : multiply # of cells to get bytes )
: cell- cell - ; ( a -- a : decrement address by cell width )
: execute 2/ >r ; ( xt -- : execute an execution token )
: ?exit if rdrop then ; compile-only ( u --, R: -- |??? )
:s @execute ?dup 0= ?exit @ execute ;s ( xt -- )
: key? pause #-1 [@] negate ( -- c -1 | 0 : get byte of input )
   s>d if
     [ {options} ] literal @
     [ 0 sys.eof ] literal and if bye then drop #0 exit
   then #-1 ;
: key begin <key> @execute until ; ( -- c )
: emit <emit> @execute ; ( c -- : output byte )
: cr ( -- : emit new line )
  [ =cr ] literal emit 
  [ =lf ] literal emit ;
: get-current current @ ; ( -- wid : get definitions vocab. )
: set-current current ! ; ( -- wid : set definitions vocab. )
:s last get-current @ ;s ( -- wid : get last defined word )
: pick sp@ + [@] ; ( nu...n0 u -- nu : pick item on stack )
: +! 2/ tuck [@] + swap [!] ; ( u a -- : add val to cell )
: lshift negate shift ; ( u n -- u : left shift 'u' by 'n' )
: c@ ( a -- c : character load )
  @+ swap #1 and if
    [ 8 ] literal rshift exit
  then [ FF ] literal and ;
: c! swap [ FF ] literal and dup [ 8 ] literal lshift or swap
   tuck @+ swap #1 and 0= [ FF ] literal xor
   >r over xor r> and xor swap ! ; ( c a -- character store )
:s c@+ dup c@ ;s ( b -- b u : non-destructive 'c@' )
: max 2dup > mux ; ( n1 n2 -- n : highest of two numbers )
: min 2dup < mux ; ( n1 n2 -- n : lowest of two numbers )
: source-id [ {id} ] up @ ; ( -- u : input type )
: 2! tuck ! cell+ ! ; ( u1 u2 a -- : store two cells )
: 2@ dup cell+ @ swap @ ; ( a -- u1 u2 : fetch two cells )
: 2>r r> swap >r swap >r >r ; compile-only ( n n --,R: -- n n )
: 2r> r> r> swap r> swap >r ; compile-only ( -- n n,R: n n -- )
system[ user tup =cell tallot ]system
: source tup 2@ ; ( -- a u : get terminal input source )
: aligned dup #1 and 0<> #1 and + ; ( u -- u : align up ptr. )
: align here aligned h? ! ; ( -- : align up dict. ptr. )
: allot h? +! ; ( n -- : allocate space in dictionary )
: , align here ! cell allot ; ( u -- : write value into dict. )
: c, here c! #1 allot ; ( c -- : write character into dict. )
: count dup 1+ swap c@ ; ( b -- b c : advance string )
: +string #1 over min rot over + -rot - ; ( b u -- b u )
:s .emit ( c -- : print char, replacing non-graphic ones )
  dup bl [ $7F ] literal within [char] . swap mux emit ;s
: type 1- for count emit next drop ;
: cmove ( b1 b2 n -- : move character blocks around )
  #0 max for aft >r c@+ r@ c! 1+ r> 1+ then next 2drop ;
: fill ( b n c -- : write byte 'c' to array 'b' of 'u' length )
  swap #0 max for swap aft 2dup c! 1+ then next 2drop ;
: erase #0 fill ; ( b u -- : write zeros to array )
:s do$ 2r> 2* dup count + aligned 2/ >r swap >r ;s ( -- a  )
:s ($) do$ ;s           ( -- a : do string )
:s .$ do$ count type ;s ( -- : print string in next cells )
:m ." .$ $literal ;m ( --, ccc" : compile string )
:m $" ($) $literal ;m ( --, ccc" : compile string )
: space bl emit ; ( -- : emit a space )
: catch        ( xt -- exception# | 0 \ return addr on stack )
   sp@ >r                 ( xt )  \ save data stack pointer
   [ {handler} ] up @ >r  ( xt )  \ and previous handler
   rp@ [ {handler} ] up ! ( xt )  \ set current handler
   execute                ( )     \ execute returns if no throw
   r> [ {handler} ] up !  ( )     \ restore previous handler
   rdrop                  ( )     \ discard saved stack ptr
   #0 ;                   ( 0 )   \ normal completion
: throw ( ??? exception# -- ??? exception# )
  ?dup if              ( exc# )     \ 0 throw is no-op
    [ {handler} ] up @ rp! ( exc# ) \ restore prev ret. stack
    r> [ {handler} ] up !  ( exc# ) \ restore prev handler
    r> swap >r         ( saved-sp ) \ exc# on return stack
    sp! r>        ( exc# )     \ restore stack
  then ;
: abort #-1 throw ; ( -- : Time to die. )
:s (abort) do$ swap if count type abort then drop ;s ( n -- )
:s depth [ {sp0} ] literal @ sp@ - 1- ;s ( -- n : stk. depth )
:s ?depth depth >= [ -$4 ] literal and throw ;s ( ??? n -- )
: um+ 2dup + >r r@ 0>= >r ( u u -- u carry )
  2dup and 0< r> or >r or 0< r> and negate r> swap ;
: dnegate invert >r invert #1 um+ r> + ; ( d -- d )
: d+ >r swap >r um+ r> + r> + ; ( d d -- d )
: um* ( u u -- ud : double cell width multiply )
  #0 swap ( u1 0 u2 ) 
  [ $F ] literal for ( 16 times )
    dup um+ 2>r dup um+ r> + r>
    if >r over um+ r> + then
  next shed ;
: * um* drop ; ( n n -- n : multiply two numbers )
: um/mod ( ud u -- ur uq : unsigned double cell div/mod )
  ?dup 0= [ -$A ] literal and throw ( divisor is non zero? )
  2dup u<
  if 
    negate 
    [ $F ] literal for ( 16 times )
      >r dup um+ 2>r dup um+ r> + dup
      r> r@ swap >r um+ r> ( or -> ) 0<> swap 0<> +
      if >r drop 1+ r> else drop then r>
    next
    drop swap exit
  then 2drop drop #-1 dup ;
: m/mod ( d n -- r q : floored division, hopefully not flawed )
  s>d dup >r
  if negate >r dnegate r> then
  >r s>d if r@ + then r> um/mod r> ( modify um/mod result )
  if swap negate swap then ;
: /mod over 0< swap m/mod ; ( u1 u2 -- u1%u2 u1/u2 )
: mod /mod drop ; ( u1 u2 -- u1%u2 )
: /   /mod nip ; ( u1 u2 -- u1/u2 )
:s (emit) pause #-1 out! ;s ( c -- : output byte to terminal )
: echo <echo> @execute ; ( c -- : emit a single character )
:s tap dup echo over c! 1+ ;s ( bot eot cur c -- bot eot cur )
:s ktap ( bot eot cur c -- bot eot cur )
  ( Not EOL? )
  dup dup [ =cr ] literal <> >r [ =lf ] literal  <> r> and if
    ( Not Del Char? )
    dup [ =bksp ] literal <> >r [ =del ] literal <> r> and if
      bl tap ( replace any other character with bl )
      exit
    then
    >r over r@ < dup if ( if not at start of line )
      [ =bksp ] literal dup echo bl echo echo ( erase char )
    then
    r> + ( add 0/-1 to cur )
    exit
  then drop nip dup ;s ( set cur = eot )
: accept ( b u -- b u : read in a line of user input )
  over + over begin
    2dup <>
  while
    key dup 
    bl - [ $5F ] literal u< ( magic: within 32-127? )
    if tap else <tap> @execute then
  repeat drop over - ;
: expect <expect> @execute span ! drop ; ( a u -- )
: tib source drop ; ( -- b : get Terminal Input Buffer )
: query ( -- : get a new line of input, store it in TIB )
  tib [ =buf ] literal <expect> @execute tup ! drop #0 >in ! ;
: -trailing for aft ( b u -- b u : remove trailing spaces )
     bl over r@ + c@ < if r> 1+ exit then
   then next #0 ;
:s look ( b u c xt -- b u : skip until *xt* test succeeds )
  swap >r -rot
  begin
    dup
  while
    over c@ r@ - r@ bl = [ 4 ] literal pick execute
    if rdrop shed exit then
    +string
  repeat rdrop shed ;s
:s unmatch if 0> exit then 0<> ;s ( c1 c2 -- t )
:s match unmatch invert ;s        ( c1 c2 -- t )
: parse ( c -- b u ; <string> )
  >r tib >in @ + tup @ >in @ - r@ ( get memory to parse )
  >r over r> swap 2>r
  r@ [ t' unmatch ] literal look 2dup ( find start of match )
  r> [ t' match   ] literal look swap ( find end of match )
    r> - >r - r> 1+ ( b u c -- b u delta : compute match len )
  >in +!
  r> bl = if -trailing then
  #0 max ;
:s banner ( +n c -- : output 'c' 'n' times )
  >r begin dup 0> while r@ emit 1- repeat drop rdrop ;s
: hold #-1 hld +! hld @ c! ; ( c -- : save char in hold space )
: #> 2drop hld @ this [ =num ] literal + over - ; ( d -- b u )
:s extract ( ud ud -- ud u : extract digit from number )
  dup >r um/mod r> swap >r um/mod r> rot ;s
:s digit ( u -- c : extract a character from number )
  [ 9 ] literal over < [ 7 ] literal and + [char] 0 + ;s
: #  #2 ?depth #0 radix extract digit hold ; ( d -- d )
: #s begin # 2dup ( d0= -> ) or 0= until ; ( d -- 0 0 )
: <# this [ =num ] literal + hld ! ; ( -- : start num. output )
: sign 0>= ?exit [char] - hold ; ( n -- )
: u.r >r #0 <# #s #> r> over - bl banner type ; ( u r -- )
: u. space #0 u.r ; ( u -- : unsigned numeric output )
opt.divmod [if]
:s (.) abs radix opDivMod ?dup if (.) then digit emit ;s
: . space s>d if [char] - emit then (.) ; ( n -- )
[else]
: . space dup >r abs #0 <# #s r> sign #> type ; ( n -- )
[then]
: >number ( ud b u -- ud b u : convert string to number )
  dup 0= ?exit
  begin
    2dup 2>r drop c@ radix ( get next character )
    ( digit? -> ) >r [char] 0 - [ 9 ] literal over <
    if
    ( next line: c base -- u f )
    [ 7 ] literal - dup [ $A ] literal < or then dup r> u<
    0= if                            ( d char )
      drop                           ( d char -- d )
      2r>                            ( restore string )
      exit                           ( finished...exit )
    then                             ( d char )
    swap radix um* drop rot radix um* d+ ( accumulate digit )
    2r>                              ( restore string )
    +string dup 0=                   ( advance, test for end )
  until ;
: number? ( a u -- d -1 | a u 0 : easier to use than >number )
  #-1 dpl !
  radix >r
  over c@ [char] - = dup >r if +string then
  over c@ [char] $ = if hex +string 
    ( dup 0= if dup rdrop r> base ! exit then ) 
  then
  2>r #0 dup 2r>
  begin
    >number dup
  while over c@ [char] . <>
    if shed rot r> 2drop #0 r> base ! exit then
    1- dpl ! 1+ dpl @
  repeat
  2drop r> if dnegate then r> base ! #-1 ;
: .s depth for aft r@ pick . then next ; ( -- : show stack )
: compare ( a1 u1 a2 u2 -- n : string comparison )
  rot
  over - ?dup if >r 2drop r> nip exit then
  for ( a1 a2 )
    aft
      count rot count rot - ?dup
      if rdrop nip nip exit then
    then
  next 2drop #0 ;
: nfa cell+ ; ( pwd -- nfa : move word ptr to name field )
: cfa ( pwd -- cfa : move to Code Field Address )
  nfa c@+ [ 1F ] literal and + cell+ -cell and ;
:s (search) ( a wid -- PWD PWD 1 | PWD PWD -1 | 0 a 0 )
  \ Search for word "a" in "wid"
  swap >r dup
  begin
    dup
  while
    ( $9F = $1F:word-length + $80:hidden )
    dup nfa count [ $9F ] literal
    and r@ count compare 0=
    if ( found! )
      rdrop
      dup ( immediate? -> ) nfa [ $40 ] literal swap @ and 0<>
      #1 or negate exit
    then
    nip @+
  repeat
  rdrop 2drop #0 ;s
:s (find) ( a -- pwd pwd 1 | pwd pwd -1 | 0 a 0 : find a word )
  >r
  context
  begin
    @+
  while
    @+ @ r@ swap (search) ?dup
    if
      >r shed r> rdrop exit
    then
    cell+
  repeat drop #0 r> #0 ;s
: search-wordlist ( a wid -- PWD 1|PWD -1|a 0 )
   (search) shed ;
: find ( a -- pwd 1 | pwd -1 | a 0 : find word in dictionary )
  (find) shed ;
: compile r> dup [@] , 1+ >r ; compile-only ( -- )
:s (literal) state @ if compile (push) , then ;s ( u -- )
:to literal <literal> @execute ; immediate ( u -- )
: compile, ( align <- called by "," ) 2/ , ;  ( xt -- )
:s ?found ?exit ( b f -- b | ??? )
   space count type [char] ? emit cr [ -$D ] literal throw ;s
: interpret ( b -- : interpret a counted word )
  find ?dup if
    state @
    if
      0> if cfa execute exit then \ <- execute immediate words
      cfa compile, exit \ <- compiling word are...compiled.
    then
    drop
    ( next line performs "?compile" )
    dup nfa c@ [ 20 ] literal and 0<> [ -$E ] literal and throw
    \ if it's not compiling, execute it then exit *interpreter*
    cfa execute exit
  then
  \ not a word
  dup >r count number? if rdrop \ it is numeric!
    dpl @ 0< if \ <- dpl is -1 if it's a single cell number
      drop     \ drop high cell from 'number?' for single cell
    else       \ <- dpl is not -1, it is a double cell number
      state @ if swap then
      postpone literal \ literal executed twice if # is double
    then \ N.B. "literal" is state aware
    postpone literal exit
  then
  \ N.B. Could vector ?found here, to handle arbitrary words
  r> #0 ?found ;
: get-order ( -- widn...wid1 n : get current search order )
  context
   \ next line finds first empty cell
  #0 >r begin @+ r@ xor while cell+ repeat rdrop
  dup cell- swap
  context - 2/ dup >r 1- s>d [ -$32 ] literal and throw
  for aft @+ swap cell- then next @ r> ;
:r set-order ( widn ... wid1 n -- : set current search order )
  \ N.B. Uses recursion, however the meta-compiler does not use
  \ the Forth compilation mechanism, so the current definition
  \ of "set-order" is available immediately.
  dup #-1 = if drop root-voc #1 set-order exit then
  dup #vocs > [ -$31 ] literal and throw
  context swap for aft tuck ! cell+ then next #0 swap ! ;r
: (order) ( w wid*n n -- wid*n w n )
  dup if
    1- swap >r ( recurse -> ) (order) over r@ xor
    if 1+ r> -rot exit then rdrop
  then ;
: -order ( wid -- : remove vocabulary from search order )
  get-order (order) nip set-order ;
: +order ( wid -- : add vocabulary to search order )
  dup >r -order get-order r> swap 1+ set-order ;
root[
  {forth-wordlist} constant forth-wordlist ( -- wid )
          {system} constant system         ( -- wid )
]root
:r forth ( -- : set system to contain default vocabularies )
   root-voc forth-wordlist #2 set-order ;r
:r only #-1 set-order ;r ( -- : set minimal search order )
:s .id ( pwd -- : print word )
  nfa count [ $1F ] literal and type space ;s
:r words ( -- : list all words in all loaded vocabularies )
  cr get-order
  begin ?dup while swap ( dup u. ." : " ) @
    begin ?dup
    while dup nfa c@ [ $80 ] literal and 0= if dup .id then @
    repeat ( cr )
  1- repeat ;r
: definitions context @ set-current ; ( -- )
: word ( c -- b : parse a character delimited word )
  #1 ?depth parse here aligned dup >r 2dup ! 1+ swap cmove r> ;
:s token bl word ;s ( -- b : get space delimited word )
:s ?unique ( b -- b : warn if word definition is not unique )
 dup get-current (search) 0= ?exit space
 2drop [ {last} ] literal @ .id ." redefined" cr ;s ( b -- b )
:s ?nul ( b -- b : check not null )
   c@+ ?exit [ -$10 ] literal throw ;s
:s ?len ( b -- b )
  c@+ [ 1F ] literal > [ -$13 ] literal and throw ;s
:to char token ?nul count drop c@ ; ( "name", -- c )
:to [char] postpone char compile (push) , ; immediate
:to ; ( -- : end a word definition )
  ( next line: check compiler safety )
  [ $CAFE ] literal <> [ -$16 ] literal and throw
  [ =unnest ] literal ,          ( compile exit )
  postpone [                     ( back to command mode )
  ?dup if                        ( link word in if non 0 )
    get-current !                ( this inks the word in )
  then ; immediate compile-only
:to :   ( "name", -- colon-sys )
  align                 ( must be aligned before hand )
  here dup              ( push location for ";" )
  [ {last} ] literal !  ( set last defined word )
  last ,                ( point to previous word in header )
  token ?nul ?len ?unique ( parse word and do basic checks )
  count + h? ! align    ( skip over packed word and align )
  [ $CAFE ] literal     ( push constant for compiler safety )
  postpone ] ;          ( turn compile mode on )
:to :noname ( "name", -- xt : make a definition with no name )
  align here #0 [ $CAFE ] literal postpone ] ;
:to ' ( "name" -- xt : get xt of word [or throw] )
  token find ?found cfa ;
:to recurse ( -- : recursive call to current definition )
    [ {last} ] literal @ cfa compile, ; immediate compile-only
:s toggle tuck @ xor swap ! ;s ( u a -- : toggle bits at addr )
:s hide token find ?found nfa [ $80 ] literal swap toggle ;s
:s mark here #0 , ;s compile-only
:to begin here ; immediate compile-only
:to if [ =jumpz ] literal , mark ; immediate compile-only
:to until 2/ postpone if ! ; immediate compile-only
:to again [ =jump ] literal , compile, ; immediate compile-only
:to then here 2/ swap ! ; immediate compile-only
:to while postpone if ; immediate compile-only
:to repeat swap postpone again postpone then ;
    immediate compile-only
:to else [ =jump ] literal , mark swap postpone then ;
    immediate compile-only
:to for [ =>r ] literal , here ; immediate compile-only
:to aft drop [ =jump ] literal , mark here swap ;
    immediate compile-only
:to next [ =next ] literal , compile, ; immediate compile-only
:s (marker) r> 2* @+ h? ! cell+ @ get-current ! ;s compile-only
: create state @ >r postpone : drop r> state ! compile (var)
   get-current ! ;
:to variable create #0 , ;
:to constant create -cell allot compile (const) , ;
:to user create -cell allot compile (user)
   cell user? +! user? @ , ;
: >body cell+ ; ( a -- a : move to a created words body )
:s (does) 2r> 2* swap >r ;s compile-only
:s (comp)
  r> [ {last} ] literal @ cfa
  ! ;s compile-only
: does> compile (comp) compile (does) ;
   immediate compile-only
:to marker last align here create -cell allot compile
    (marker) , , ; ( --, "name" )
:to >r compile opToR ; immediate compile-only
:to r> compile opFromR ; immediate compile-only
:to rdrop compile rdrop ; immediate compile-only
:to exit compile opExit ; immediate compile-only
:s (s) align [char] " word count nip 1+ allot align ;s
:to ." compile .$ (s) ; immediate compile-only
:to $" compile ($) (s) ; immediate compile-only
:to abort" compile (abort) (s) ; immediate compile-only
:to ( [char] ) parse 2drop ; immediate ( c"xxx" -- )
:to .( [char] ) parse type ; immediate ( c"xxx" -- )
:to \ tib @ >in ! ; immediate ( c"xxx" -- )
:to postpone token find ?found cfa compile, ; immediate
:s (nfa) last nfa toggle ;s ( u -- )
:to immediate ( -- : mark prev word as immediate )
  [ $40 ] literal (nfa) ;
:to compile-only ( -- : mark prev word as compile-only )
  [ $20 ] literal (nfa) ;
opt.better-see [unless]
:to see token find ?found cr ( --, "name" : decompile  word )
  begin @+ [ =unnest ] literal <>
  while @+ . cell+ here over < if drop exit then
  repeat @ u. ;
[then]
opt.better-see [if] ( Start conditional compilation )
:s ndrop for aft drop then next ;s ( x0...xn n -- )
:s validate ( pwd cfa -- nfa | 0 )
  over cfa <> if drop #0 exit then nfa ;s
:s cfa? ( wid cfa -- nfa | 0 : search for CFA in a wordlist )
  cells >r
  begin
    dup
  while
    dup @ over r@ -rot within
    if dup @ r@ validate ?dup if rdrop nip exit then then
    @
  repeat rdrop ;s
:s name ( cwf -- a | 0 : search for CFA in the dictionary )
  >r
  get-order
  begin
    dup
  while
    swap r@ cfa? ?dup if
      >r 1- ndrop r> rdrop exit then
  1- repeat rdrop ;s
:s instruction ( u -- )
  [ primitive ] literal @ over u> if ."  VM    " 2* else
    dup name ?dup if space count [ $1F ] literal
    and type drop exit then
  then
  u. ;s
:s decompile ( a u -- a )
  dup [ =jumpz ] literal = if
    drop ."  jumpz " cell+ dup @ 2* u. exit
  then
  dup [ =jump ] literal = if
    drop ."  jump  " cell+ dup @ 2* u. exit
  then
  dup [ =next ] literal = if
    drop ."  next  " cell+ dup @ 2* u. exit
  then
  dup [ to' compile half ] literal = if
     drop ."  compile" cell+ dup @ instruction exit 
  then
  dup [ to' (up) half ] literal = if drop
     ."  (up) " cell+ dup @ u. exit
  then
  dup [ to' (push) half ] literal = if drop
     ."  (push) " cell+ dup @ u. exit
  then
  dup [ to' (user) half ] literal = if drop
     ."  (user) " cell+ @ u. [ $7FFF ] literal exit
  then
  dup [ to' (const) half ] literal = if drop
     ."  (const) " cell+ @ u. [ $7FFF ] literal exit
  then
  dup [ to' (var) half ] literal = if drop
     ."  (var) " cell+ dup u. ."  -> " @ . [ $7FFF ] literal
     exit
  then
  dup [ to' .$ half ] literal = if drop ."  ." [char] "
    emit space
    cell+ count 2dup type [char] " emit + aligned cell -
  exit then
  dup [ to' ($) half ] literal = if drop ."  $" [char] "
  emit space
    cell+ count 2dup type [char] " emit + aligned cell -
  exit then
  instruction ;s
:s compile-only? ( pwd -- f )
   nfa [ $20 ] literal swap @ and 0<> ;s
:s immediate? ( pwd -- f )
  nfa [ $40 ] literal swap @ and 0<> ;s
:to see token dup find ?found swap ." : " count type cr
  dup >r cfa
  begin dup @ [ =unnest ] literal <>
  while
    dup dup [ $5 ] literal u.r ."  | "
    @ decompile cr cell+ here over u< if drop rdrop exit then
  repeat drop ."  ;"
  r> dup immediate? if ."  immediate" then
  compile-only? if ."  compile-only" then cr ;
[then] ( End conditional compilation of entire section )
: dump aligned ( a u -- : display section of memory )
  begin ?dup
  while swap @+ . cell+ swap cell-
  repeat drop ;
:s cksum aligned dup [ $C0DE ] literal - >r ( a u -- u )
  begin ?dup
  while swap @+ r> + >r cell+ swap cell-
  repeat drop r> ;s
: defined token find nip 0<> ; ( -- f  )
:to [then] ; immediate ( -- : end [if]...[else]...[then] )
:to [else] ( -- : skip until '[then]' )
 begin
  begin token c@+ while
   find drop cfa dup
    [ to' [else] ] literal = swap [ to' [then] ] literal = or
    ?exit repeat query drop again ; immediate
:to [if] ?exit postpone [else] ; immediate
: ms for pause calibration @ for next next ; ( ms -- )
: bell [ $7 ] literal emit ; ( -- : emit ASCII BEL character )
:s csi ( -- : ANSI Term. Esc. Seq. )
  [ $1B ] literal emit [ $5B ] literal emit ;s
: page csi ." 2J" csi ." 1;1H" ( csi ." 0m" ) ;
: at-xy radix decimal ( x y -- : set cursor position )
   >r csi #0 u.r ." ;" #0 u.r ." H" r> base ! ;
$400 constant b/buf ( -- u : size of the block buffer )
system[
$200 constant c/buf  ( -- cu : cells in the block buffer )
variable <block>     ( -- a : xt for "block" word )
$F400 constant buf0  ( -- ca : location of block buffer )
variable dirty0      ( -- a : is block buffer dirty? )
variable blk0        ( -- a : what block is stored in buffer? )
-1 t' blk0 >tbody t! ( set initial loaded block to be invalid )
]system
:s (block) ( ca ca cu -- : transfer to/from "mass storage" )
  pause ( pause for multitasking )
  for 
    aft 2dup [@] swap [!] 1+ swap 1+ swap
    then
  next 2drop ;s
t' (block) t' <block> >tbody t!
( :s swap? 0= ?exit swap ;s ( x y sel -- x y | y x )
:s valid? dup #1 [ $80 ] literal within ;s ( k -- k f )
:s transfer <block> @ execute ;s ( a a u -- )
:s >blk 1- c/buf * ;s ( k -- ca )
:s clean #0 dirty0 ! ;s ( -- : opposite of 'update' )
:s invalidate #-1 blk0 ! ;s ( -- : store invalid block # )
:s bput valid? if >blk buf0 2/ c/buf transfer exit then drop ;s
:s bget 
  valid? if >blk buf0 2/ swap c/buf transfer exit then drop ;s
:s loaded? dup blk0 @ = ;s ( k -- k f )
: update #-1 dirty0 ! ; ( -- )
: save-buffers dirty0 @ if blk0 @ bput clean then ; ( -- )
: flush save-buffers invalidate ; ( -- )
: empty-buffers clean invalidate ; ( -- )
: buffer ( k -- a )
  #1 ?depth                      ( sanity check stack depth )
  valid?                         ( validity check )
  0= [ -$23 ] literal and throw  ( throw if invalid )
  loaded? if drop buf0 exit then ( already loaded )
  save-buffers                   ( save buffer if dirty )
  blk0 !                         ( set current loaded block )
  buf0 ;                         ( return block buffer loc. )
: block
  loaded? if drop buf0 exit then ( already loaded )
  dup buffer swap bget ; ( k -- a )
: blank bl fill ; ( a u -- : blank an area of memory )
: list ( k -- : display a block )
   page cr         ( clean the screen )
   dup >r block ( save block number and call "block" )
   [ $F ] literal for       ( for each line in the block )
     [ $F ] literal r@ - [ $3 ] literal u.r space
     [ $3F ] literal for count .emit next cr ( print line )
   next drop r> scr ! ;
: get-input source >in @ source-id <ok> @ ; ( -- n1...n5 )
: set-input <ok> ! [ {id} ] up ! >in ! tup 2! ; ( n1...n5 -- )
:s ok state @ ?exit ."  ok" cr ;s ( -- : okay prompt )
:s eval ( "word" -- )
   begin token c@+ while
     interpret #0 ?depth
   repeat drop <ok> @execute ;s
: evaluate ( a u -- : evaluate a string )
  get-input 2>r 2>r >r       ( save the current input state )
  #0 #-1 [ to' ) ] literal set-input ( set new input )
  [ t' eval ] literal catch  ( evaluate the string )
  r> 2r> 2r> set-input       ( restore input state )
  throw ;                    ( throw on error )
:s line ( k l -- a u )
  [ $6 ] literal lshift swap block + [ $40 ] literal ;s
:s loadline line evaluate ;s ( k l -- ??? : execute a line! )
: load ( k -- : execute a block )
   blk @ >r dup blk ! #0 [ $F ] literal for
   2dup 2>r loadline 2r> 1+ next 2drop r> blk ! ;
root[
  $0200 constant eforth ( --, version )
]root
opt.info [if]
  :s info  ( --, print system info )
    cr
    ." eForth v2.0, Public Domain,"  here . cr
    ." Richard James Howe, howe.r.j.89@gmail.com" cr
    ." https://github.com/howerj/subleq" cr ;s
[else]
  :s info ;s ( --, [disabled] print system info )
[then]
:s xio ( xt xt xt -- : exchange I/O )
  [ t' accept ] literal <expect> ! <tap> ! <echo> ! <ok> ! ;s
:s hand ( -- )
  [ t' ok ] lit
  [ t' (emit) ] literal [ to' drop ] literal
  [ {options} ] literal @ #1 and 0= mux  ( Default: echo on )
  [ t' ktap ] literal postpone [ xio ;s
:s pace [ $B ] literal emit ;s ( -- : emit pacing character )
:s file ( -- )
  [ t' pace ] literal
  [ to' drop ] literal
  [ t' ktap ] literal xio ;s
:s console
  [ t' key? ] literal <key> !
  [ t' (emit) ] literal <emit> !
  hand ;s
:s io! console ;s ( -- : setup system I/O )
:s task-init ( task-addr -- : initialize USER task )
  [ {up} ] literal @ swap [ {up} ] literal !
  this 2/ [ {next-task} ] up !
  \ Default xt token )
  [ to' bye ] literal 2/ [ {ip-save} ] up !
  this [ =stksz        ] literal + 2/ [ {rp-save} ] up !
  this [ =stksz double ] literal + 2/ [ {sp-save} ] up !
  #0 [ {tos-save} ] up !
  decimal
  io!
  [ t' (literal) ] literal <literal> !
  opt.float [if] [ $3 ]  literal [ {precision} ] up ! [then]
  [ to' bye ] literal <error> !
  #0 >in ! #-1 dpl !
  \ Set terminal input buffer loc.
  this [ =tib ] literal + #0 tup 2!
  [ {up} ] literal ! ;s
:s ini ( -- : initialize current task )
   [ {up} ] literal @ task-init ;s
:s (error) ( u -- : quit loop error handler )
   dup space . [char] ? emit cr #-1 = if bye then
   ini [ t' (error) ] literal <error> ! ;s
: quit ( -- : interpreter loop )
  [ t' (error) ] literal <error> ! ( set error handler )
  begin                          ( infinite loop start... )
   query [ t' eval ] literal catch ( evaluate a line )
   ?dup if <error> @execute then ( error? )
  again ;                        ( do it all again... )
:s (boot) ( -- : Forth boot sequence )
  forth definitions ( un-mess-up dictionary / set it )
  ini ( initialize the current thread correctly )
  opt.self [if]
    [ {options} ] literal @ [ $10 ] literal and if 
      \ Print out warning if we are running a virtualized
      \ and thus very slow system
      [ {virtual} ] literal @ if
        ." Warning: Virtual 16-bit SUBLEQ VM" cr
      then
    then
  [then]
  [ {options} ] literal @ [ 4 ] literal and if info then
  [ {options} ] literal @ #2 and if ( checksum on? )
  [ primitive ] literal @ 2* dup here swap - cksum
  [ check ] literal @ <> if ." bad cksum" bye then ( oops... )
  [ {options} ] literal @ #2 xor [ {options} ] literal !
  then 
  <quit> @ execute ;s ( call the interpreter loop AKA "quit" )
opt.multi [if]
:s task: ( "name" -- : create a named task )
  create here b/buf allot 2/ task-init ;s
:s activate ( xt task-address -- : start task executing xt )
  dup task-init
  ( set execution word )
  dup >r swap 2/ swap [ {ip-save} ] literal + !
  r> this @ >r dup 2/ this ! r> swap ! ;s ( link in task )
[then]
opt.multi [if]
:s wait ( addr -- : wait for signal )
  begin pause @+ until #0 swap ! ;s
:s signal this swap ! ;s ( addr -- : signal to wait )
[then]
opt.multi [if]
:s single ( -- : disable other tasks )
   #1 [ {single} ] literal ! ;s
:s multi  ( -- : enable multitasking )
   #0 [ {single} ] literal ! ;s
[then]
opt.multi [if]
:s send ( msg task-addr -- : send message to task )
  this over [ {sender} ] literal + ( msg this msg-addr )
  begin pause @+ 0= until  ( pause until zero )
  ! [ {message} literal + ! ;s   ( send message )
:s receive ( -- msg task-addr : block until message )
  begin pause [ {sender} ] up @ until ( wait until non-zero )
  [ {message} ] up @ [ {sender} ] up @
  #0 [ {sender} ] up ! ;s
[then]
opt.editor [if]
: editor [ {editor} ] literal +order ; ( BLOCK editor )
:e q [ {editor} ] literal -order ;e ( -- : quit editor )
:e ? scr @ . ;e    ( -- : print block number of current block )
:e l scr @ list ;e ( -- : list current block )
:e x q scr @ load editor ;e ( -- : evaluate current block )
:e ia #2 ?depth [ $6 ] literal lshift + scr @ block + tib
  >in @ + swap source nip >in @ - cmove tib @ >in ! l ;e
:e a #0 swap ia ;e ( line --, "line" : insert line at )
:e w get-order [ {editor} ] literal #1 ( -- : list cmds )
     set-order words set-order ;e 
:e s update flush ;e ( -- : save edited block )
:e n  #1 scr +! l ;e ( -- : display next block )
:e p #-1 scr +! l ;e ( -- : display previous block )
:e r scr ! l ;e ( k -- : retrieve given block )
:e z scr @ block b/buf blank l ;e ( -- : erase current block )
:e d #1 ?depth >r scr @ block r> [ $6 ] literal lshift +
   [ $40 ] literal blank l ;e ( line -- : delete line )
[then]
opt.control [if]
: rpick ( n -- u, R: ??? -- ??? : pick a value off ret. stk. )
  rp@ swap - 1- 2* @ ;
: many #0 >in ! ; ( -- : repeat current line )
:s (case) r> swap >r >r ;s compile-only
:s (of) r> r@ swap >r = ;s compile-only
:s (endcase) r> r> drop >r ;s
: case compile (case) [ $1E ] literal ; compile-only immediate
: of compile (of) postpone if ; compile-only immediate
: endof postpone else [ $1F ] literal ; compile-only immediate
: endcase
   begin
    dup [ $1F ] literal =
   while
    drop
    postpone then
   repeat
   [ $1E ] literal <> [ -$16 ] literal and throw
   compile (endcase) ; compile-only immediate
:s r+ 1+ ;s ( N.B. Should be cell+ on most platforms )
:s (unloop) r> rdrop rdrop rdrop >r ;s compile-only
:s (leave) rdrop rdrop rdrop ;s compile-only
:s (j) [ $4 ] literal rpick ;s compile-only
:s (k) [ $7 ] literal rpick ;s compile-only
:s (do) r> dup >r swap rot >r >r r+ >r ;s compile-only
:s (?do)
   2dup <> if
     r> dup >r swap rot >r >r r+ >r exit
   then 2drop ;s compile-only
:s (loop)
  r> r> 1+ r> 2dup <> if
    >r >r 2* @ >r exit \ N.B. 2* and 2/ cause porting problems
  then >r 1- >r r+ >r ;s compile-only
:s (+loop)
   r> swap r> r> 2dup - >r
   #2 pick r@ + r@ xor 0>=
   [ $3 ] literal pick r> xor 0>= or if
     >r + >r 2* @ >r exit
   then >r >r drop r+ >r ;s compile-only
: unloop compile (unloop) ; immediate compile-only
: i compile r@ ; immediate compile-only ( current loop count )
: j compile (j) ; immediate compile-only ( nested loop count )
: k compile (k) ; immediate compile-only ( nested+1 loop cnt )
: leave compile (leave) ; immediate compile-only
: do compile (do) #0 , here ; immediate compile-only
: ?do compile (?do) #0 , here ; immediate compile-only
: loop ( increment loop count )
  compile (loop) dup 2/ ,
  compile (unloop)
  cell- here cell- 2/ swap ! ; immediate compile-only
: +loop ( increment loop by amount )
  compile (+loop) dup 2/ ,
  compile (unloop)
  cell- here cell- 2/ swap ! ; immediate compile-only
:s scopy ( b u -- b u : copy a string into the dictionary )
  align here >r aligned dup allot
  r@ swap dup >r cmove r> r> swap ;s
:s (macro) r> 2* 2@ swap evaluate ;s
: macro ( c" xxx" --, : create a late-binding macro )
  create postpone immediate
  -cell allot compile (macro)
  align here #2 cells + ,
  #0 parse dup , scopy 2drop ;
[then] ( opt.control )
opt.allocate [if]
system[
  ( pointer to beginning of free space )
variable freelist 0 t, 0 t, ( 0 t' freelist t! )
: >length #2 cells + ; ( freelist -- length-field )
: pool ( default memory pool )
  [ $F800 ] literal [ $400 ] literal ;
: arena! ( start-addr len -- : initialize memory pool )
  >r dup [ $80 ] literal u< if
    [ -$B ] literal throw ( arena too small )
  then
  dup r@ >length !
  2dup erase
  over dup r> ! #0 swap ! swap cell+ ! ;
: arena? ( ptr freelist -- f : is "ptr" within arena? )
  dup >r @ 0= if rdrop drop #0 exit then
  r> swap >r dup >r @ dup r> >length @ + r> within ;
: >size ( ptr freelist -- size : get size of allocated ptr )
  over swap arena? 0= if [ -$3B ] literal throw then
  cell- @ cell- ;
: (allocate) ( u -- addr ior : dynamic allocate of 'u' bytes )
  >r
  aligned
  r@ @ 0= if pool r@ arena! then ( init to default pool )
  dup 0= if rdrop drop #0 [ -$3B ] literal exit then
  cell+ r@ dup
  begin
  while dup @ cell+ @ #2 pick u<
    if
      @ @ dup ( get new link )
    else
      dup @ cell+ @ #2 pick - #2 cells max dup #2 cells =
      if
        drop dup @ dup @ rot
        ( prevent freelist address from being overwritten )
        dup r@ = if
          rdrop 2drop 2drop #0 [ -$3B ] literal exit
        then
        !
      else
        2dup swap @ cell+ ! swap @ +
      then
      2dup ! cell+ #0 ( store size, bump pointer )
    then              ( and set exit flag )
  repeat
  rdrop nip dup 0= [ -$3B ] literal and ;
: (free) ( ptr freelist -- ior : free pointer from "allocate" )
  >r
  dup 0= if rdrop #0 exit then
  dup r@ arena? 0= if rdrop drop [ -$3C ] literal exit then
  cell- dup @ swap 2dup cell+ ! r> dup
  begin
    dup [ $3 ] literal pick u< and
  while
    @ dup @
  repeat
  dup @ dup [ $3 ] literal pick ! ?dup
  if
    dup [ $3 ] literal pick [ $5 ] literal pick + =
    if
      dup cell+ @ [ $4 ] literal pick +
      [ $3 ] literal pick cell+ ! @ #2 pick !
    else
      drop
    then
  then
  dup cell+ @ over + #2 pick =
  if
    over cell+ @ over cell+ dup @ rot + swap ! swap @ swap !
  else
    !
  then
  drop #0 ;
: (resize) ( a-addr1 u freelist -- a-addr2 ior )
  >r
  dup 0= if drop r> (free) exit then
  over 0= if nip r> (allocate) exit then
  2dup swap r@ >size u<= if drop #0 exit then
  r@ (allocate) if drop [ -$3D ] literal exit then
  over r@ >size
  #1 pick [ $3 ] literal pick >r >r cmove r> r> r>
  (free) if drop [ -$3D ] literal exit then #0 ;
]system
: allocate freelist (allocate) ; ( u -- ptr ior )
: free freelist (free) ; ( ptr -- ior )
: resize freelist (resize) ; ( ptr u -- ptr ior )
[then]
:s (2const) r> 2* 2@ ;s compile-only ( R: a --, -- u )
:m 2constant :t mdrop (2const) t, t, ;m
:m 2variable :t mdrop mswap (var) t, t, munorder ;m
:m 2literal mswap lit lit ;m
:m mcreate :t mdrop (var) munorder ;m ( --, "name": var )
opt.float [if] ( Large section of optional code! )
( See <https://github.com/howerj/subleq> for more info )
( Heavily modified and extended from floating point code with )
( the following copyright notice: )
 \  FORTH-83 FLOATING POINT.
 \ ----------------------------------
 \ COPYRIGHT 1985 BY ROBERT F. ILLYES
 \       PO BOX 2516, STA. A
 \       CHAMPAIGN, IL 61820
 \       PHONE: 217/826-2734
system[
  $10 constant #bits  ( = 1 cells 8 * )
  $8000 constant #msb ( = 1 #bits 1- lshift  )
]system

: 2+ #2 + ; ( n -- n )
: 2- #2 - ; ( n -- n )
: 1+! #1 swap +! ; ( a -- )
: /string ( b u1 u2 -- b u : advance string u2 )
  over min rot over + -rot - ;
: spaces bl banner ; ( +n  -- : print space 'n' times )
: convert count >number drop ; ( +d1 addr1 -- +d2 addr2 )
: arshift ( n u -- n : arithmetic right shift )
  2dup rshift >r swap #msb and if
  [ $10 ] literal swap - #-1 swap lshift
  else drop #0 then r> or ;
: d2* over #msb and >r 2* swap 2* swap r> if #1 or then ;
: d2/ dup   #1 and >r 2/ swap 2/ r> if #msb or then swap ;
: d- dnegate d+ ; ( d d -- d : double cell subtraction )
: d= rot = -rot = and ; ( d d -- f : double cell equal )
: d0= or 0= ;     ( d -- f : double cell number equal to zero )
: d0<> d0= 0= ;   ( d -- f : double not equal to zero )
: 2swap >r -rot r> -rot ; ( n1 n2 n3 n4 -- n3 n4 n1 n2 )
: dabs s>d if dnegate then ; ( d -- ud )
: 2over ( n1 n2 n3 n4 -- n1 n2 n3 n4 n1 n2 )
  >r >r 2dup r> swap >r swap r> r> -rot ;
: 2, , , ; ( n n -- : write to values into dictionary )
:to 2constant create -cell allot compile (2const) 2, ;
:to 2variable create #0 , #0 , ; \ does> ; ( d --, Run: -- a )
:to 2literal swap postpone literal postpone literal ; immediate
:s +- 0< if negate then ;s ( n n -- n : copy sign )
: m* ( n n -- d : single to double cell multiply [16x16->32] )
  2dup xor 0< >r abs swap abs um* r> if dnegate then ;
: sm/rem ( dl dh nn -- rem quo: symmetric division )
  over >r >r         ( dl dh nn -- dl dh,   R: -- dh nn )
  dabs r@ abs um/mod ( dl dh    -- rem quo, R: dh nn -- dh nn )
  r> r@ xor +- swap r> +- swap ;
: */mod ( a b c -- rem a*b/c : double prec. intermediate val )
  >r m* r> sm/rem ;
system[
mcreate lookup ( 16 values, CORDIC atan table )
$3243 t, $1DAC t, $0FAD t, $07F5 t,
$03FE t, $01FF t, $00FF t, $007F t,
$003F t, $001F t, $000F t, $0007 t,
$0003 t, $0001 t, $0000 t, $0000 t,
$26DD constant cordic_1K ( CORDIC scaling factor )
$6487 constant hpi
variable tx variable ty variable tz
variable _x variable _y variable _z
variable _d variable _k
]system
( CORDIC: valid in range -pi/2 to pi/2, arguments in fixed )
( point format with 1 = 16384, angle is given in radians.  )
( It would be nice to get rid of the global variables )
: cordic ( angle -- sine cosine | x y -- atan sqrt )
  _z ! cordic_1K _x ! #0 _y ! #0 _k !
  [ $10 ] literal begin ?dup while
    _z @ 0< _d !
    _x @ _y @ _k @ arshift _d @ xor _d @ - - tx !
    _y @ _x @ _k @ arshift _d @ xor _d @ - + ty !
    _z @ _k @ cells lookup + @ _d @ xor _d @ - - tz !
    tx @ _x ! ty @ _y ! tz @ _z !
    _k 1+!
    1-
  repeat
  _y @ _x @ ;
: sin cordic drop ; ( rad/16384 -- sin : fixed-point sine )
: cos cordic nip ;  ( rad/16384 -- cos : fixed-point cosine )
: fabs [ $7FFF ] literal and ; ( r -- r : FP absolute value )
system[
mdecimal
mcreate ftable
         0.001 t, t,       0.010 t, t,
         0.100 t, t,       1.000 t, t,
        10.000 t, t,     100.000 t, t,
      1000.000 t, t,   10000.000 t, t,
    100000.000 t, t, 1000000.000 t, t,
mhex
]system
:s null ( f -- f : zero exponent if mantissa is )
  over 0= if drop #0 then ;s
:s norm >r 2dup or  ( normalize input float )
  if begin s>d invert
    while d2* r> 1- >r
    repeat swap 0< - ?dup
    if r> else #msb r> 1+ then
  else r> drop then ;s
:s lalign [ $20 ] literal min for aft d2/ then next ;s
:s ralign 1- ?dup if lalign then #1 #0 d+ d2/ ;s
:s tens 2* cells ftable + 2@ ;s ( a -- d )
:s shifts fabs [ $4010 ] literal - s>d invert if
   [ -$2B ] literal throw then negate ;s
:s base? ( -- : check base )
  base @ [ $A ] literal <> [ -$40 ] literal and throw ;s
:s unaligned? ( -- : chk ptr )
   dup #1 and = [ -$9 ] literal and throw ;s
:s -+ drop swap 0< if negate then ;s
: fdepth depth 2/ ;    ( -- n : number of floats, approximate )
: fcopysign #msb and nip >r fabs r> or ; ( r1 r2 -- r1 )
: floats 2* cells ;    ( u -- u )
: float+ [ 4 ] literal ( [ 1 floats ] literal ) + ; ( a -- a )
: set-precision ( +n -- : set FP decimals printed out )
  dup #0 [ 5 ] literal within if  ( check within range )
    [ {precision} ] up ! exit ( precision ok )
  then [ -$2B ] literal throw ;   ( precision un-ok )
: precision ( -- u : precision of FP values )
  [ {precision} ] up @ ;
: f@ unaligned? 2@ ;   ( a -- r : fetch FP value )
: f! unaligned? 2! ;   ( r a -- : store FP value )
: f, 2, ; ( r -- : write float into dictionary )
: falign align ;       ( -- : align the dict. to store a FP )
: faligned aligned ;   ( a -- a : align point for FP )
: fdup #2 ?depth 2dup ; ( r -- r r : FP duplicate )
: fswap [ 4 ] literal ?depth 2swap ; ( r1 r2 -- r2 r1 )
: fover [ 4 ] literal ?depth 2over ; ( r1 r2 -- r1 r2 r1 )
: f2dup fover fover ;  ( r1 r2 -- r1 r2 r1 r2 )
: ftuck fdup 2>r fswap 2r> ; ( r1 r2 -- r2 r1 r2 )
: frot 2>r fswap 2r> fswap ; ( r1 r2 r3 -- r2 r3 r1 )
: -frot frot frot ;    ( r1 r2 r3 -- r3 r1 r2 )
: fdrop #2 ?depth 2drop ; ( r -- : floating point drop )
: f2drop fdrop fdrop ; ( r1 r2 -- : FP 2drop )
: fnip fswap fdrop ;   ( r1 r2 -- r2 : FP nip )
: fnegate #msb xor null ;  ( r -- r : FP negate )
: fsign fabs over 0< if >r dnegate r> #msb or then ;
: f2* #2 ?depth 1+ null ; ( r -- r : FP times by two )
: f2/ #2 ?depth 1- null ; ( r -- r : FP divide by two )
: f*  ( r r -- r : FP multiply )
   [ $4 ] literal ?depth rot + [ $4000 ] literal
   - >r um* r> norm ;
: fsq fdup f* ;       ( r -- r : FP square )
: f0= fabs null d0= ; ( r -- r : FP equal to zero [incl -0.0] )
: um/ ( ud u -- u : ud/u and round )
  dup >r um/mod swap r> over 2* 1+ u< swap 0< or - ;
: f/ ( r1 r2 -- r1/r2 : floating point division )
  [ $4 ] literal ?depth
  fdup f0= [ -$2A ] literal and throw
  rot swap - [ $4000 ] literal + >r
  #0 -rot 2dup u<
  if  um/ r> null
  else >r d2/ fabs r> um/ r> 1+
  then ;
: f+ ( r r -- r : floating point addition )
  [ $4 ] literal ?depth
  rot 2dup >r >r fabs swap fabs -
  dup if s>d
    if rot swap negate
      r> r> swap >r >r
    then #0 swap ralign
  then swap #0 r> r@ xor 0<
  if r@ 0< if 2swap then d-
    r> fsign rot swap norm
  else d+ if 1+ 2/ #msb or r> 1+
    else r> then then ;
0 0 2constant fzero
: f- fnegate f+ ; ( r1 r2 -- t : floating point subtract )
: f< f- 0< nip ; ( r1 r2 -- t : floating point less than )
: f> fswap f< ;  ( r1 r2 -- t : floating point greater than )
: f>= f< 0= ;    ( r1 r2 -- t : FP greater or equal )
: f<= f> 0= ;    ( r1 r2 -- t : FP less than or equal )
: f= d= ;        ( r1 r2 -- t : FP exact equality )
: f0> fzero f> ; ( r1 r2 -- t : FP greater than zero )
: f0< fzero f< ; ( r1 r2 -- t : FP less than zero )
: f0<= f0> 0= ;  ( r1 r2 -- t : FP less than or equal to zero )
: f0>= f0< 0= ;  ( r1 r2 -- t : FP more than or equal to zero )
: fmin f2dup f< if fdrop exit then fnip ; ( r1 r2 -- f : min )
: fmax f2dup f> if fdrop exit then fnip ; ( r1 r2 -- f : max )
: fwithin ( r1 r2 r3 -- f : r2 <= r1 < r3 )
  frot ftuck f>= >r f<= r> and ;
: d>f ( d -- r : double to float, dOwN 2 fLoAt lul )
  [ $4020 ] literal fsign norm ;
: s>f s>d d>f ;           ( n -- r : single to float )
: f#
  base?
  >r precision tens drop um* r> shifts
  ralign precision ?dup if for aft # then next
  [char] . hold then #s rot sign ;
: f.r >r tuck <# f# #> r> over - spaces type ; ( f +n -- )
: f. space #0 f.r ; ( f -- : output floating point )
( N.B. 'f' and 'e' require "dpl" to be set correctly! )
: f ( n|d -- f : formatted double to float )
   base?
   dpl @ 0< if ( input was single number )
     #1 ?depth s>d #0 dpl !
   else ( else a double )
     #2 ?depth
   then
   d>f dpl @ tens d>f f/ ;
:to fconstant ( "name", r --, Run Time: -- r )
  f postpone 2constant ;
:to fliteral ( r --, Run: -- r : compile a literal in a word )
  f postpone 2literal ; immediate
: fix tuck #0 swap shifts ralign -+ ; ( r -- n : f>s rounding )
: f>s tuck #0 swap shifts lalign -+ ; ( r -- n : f>s truncate )
: floor  f>s s>f ; ( r -- r )
: fround fix s>f ; ( r -- r )
: fmod f2dup f/ floor f* f- ; ( r1 r2 -- r )
$8000 $4001 2constant fone ( 1.0 fconstant fone )
: f1+ fone f+ ; ( r -- r : increment FP number )
: f1- fone f- ; ( r -- r : decrement FP number )
: finv fone fswap f/ ; ( r -- r : FP 1/x )
: exp ( r -- r : raise 2.0 to the power of 'r' )
  2dup f>s dup >r s>f f-
  f2* [ $E1E5 $C010 ] 2literal ( [ -57828.0 ] fliteral )
  2over fsq [ $FA26 $400B ] 2literal ( [ 2001.18 ] fliteral )
  f+ f/
  2over f2/ f-
  [ $8AAC $4006 ] 2literal ( [ 34.6680 ] fliteral )
  f+ f/ f1+ fsq r> + ;
: fexp  ( r -- r : raise e to the power of 'r' )
  \ 1.4427 = log2(e)
  [ $B8AA $4001 ] 2literal ( [ 1.4427 ] fliteral ) f* exp ;
: falog ( r -- r )
  [ $D49A $4002 ] 2literal ( [ 3.3219 ] fliteral ) f* exp ;
:s nget ( "123" -- : get a single signed number )
  bl word dup 1+ c@ [char] - = tuck -
  #0 #0 rot convert drop ( should throw if not number... )
  -+ ;s
: fexpm1 fexp fone f- ; ( r1 -- r2 : e raised to 'r1' less 1 )
: fsinh fexpm1 fdup fdup f1+ f/ f+ f2/ ; ( r -- fsinh : h-sin )
: fcosh fexp fdup fone fswap f/ f+ f2/ ; ( r -- fcosh : h-cos )
: fsincosh fdup fsinh fswap fcosh ; ( f -- sinh cosh )
: ftanh fsincosh f/ ; ( f -- ftanh : hyperbolic tangent )
mdecimal
: e.r ( r +n -- : output scientific notation )
  >r
  tuck fabs [ 16384 ] literal tuck -
  [ 4004 ] literal [ 13301 ] literal */mod >r
  s>f [ 4004 ] literal s>f f/ exp f*
  2dup fone f<
  if [ 10 ] literal s>f f* r> 1- >r then
  <# r@ abs #0 #s r> sign 2drop
  [char] e hold f# #> r> over - spaces type ;
 : e ( f "123" -- usage "1.23 e 10", input scientific notation )
  f nget >r r@ abs [ 13301 ] literal [ 4004 ] literal */mod
  >r s>f [ 4004 ] literal s>f f/ exp r> +
  r> 0< if f/ else f* then ;
mhex
: e. space #0 e.r ;
( : fe. e. ; ( r -- : display in engineering notation )
: fs. e. ; ( r -- : display in scientific notation )
( Define some useful constants )
$C911 $4002 2constant fpi   \ Pi = 3.14159265 fconstant fpi
$C911 $4001 2constant fhpi  \ 1/2pi = 1.57079632 fconstant fhpi
$C911 $4003 2constant f2pi  \ 2pi = 6.28318530 fconstant f2pi
$ADF8 $4002 2constant fe    \ e = 2.71828182 fconstant fe
$B172 $4000 2constant fln2  \ ln[2] = 0.69314718 fconstant fln2
$935D $4002 2constant fln10 \ ln[10] 2.30258509 fconstant fln10
: fdeg ( rad -- deg : FP radians to degrees )
  f2pi f/ [ $B400 $4009 ] 2literal ( [ 360.0 ] fliteral ) f* ;
: frad ( deg -- rad : FP degrees to radians )
  [ $B400 $4009 ] 2literal ( [ 360.0 ] fliteral ) f/ f2pi f* ;
:s >cordic ( f -- n  )
   [ $8000 $400F ] 2literal ( [ 16384.0 ] fliteral ) f* f>s ;s
:s cordic> ( n -- f )
   s>f [ $8000 $400F ] 2literal ( [ 16384.0 ] fliteral ) f/ ;s
:s quadrant
  fdup fhpi f< if fdrop #0 exit then
  fdup  fpi f< if fdrop #1 exit then
      [ $96CD $4003 ] 2literal ( [ fpi fhpi f+ ] 2 literal ) f<
      if #2 exit then
  [ $3 ] literal ;s
:s >sin #2 [ $4 ] literal within if fnegate then ;s
:s >cos #1 [ $3 ] literal within if fnegate then ;s
:s scfix >r
  r@ #1 = if fnegate fpi f+ rdrop exit then
  r> [ $3 ] literal = if fnegate f2pi f+ then ;s
:s (fsincos) fhpi fmod >cordic cordic >r cordic> r> cordic> ;s
: fsincos ( rads -- sin cos )
   fdup f0< >r
   fabs
   f2pi fmod fdup quadrant dup >r scfix (fsincos)
   r@ >cos fswap r> >sin fswap
   r> if fswap fnegate fswap then ;
: fsin fsincos fdrop ; ( rads -- sin )
: fcos fsincos fnip  ; ( rads -- cos )
: ftan fsincos f/ ; ( rads -- tan )
: f~ ( r1 r2 r3 -- flag )
  fdup f0> if 2>r f- fabs 2r> f< exit then
  fdup f0= if fdrop f= exit then
  fabs 2>r f2dup fabs fswap fabs f+ 2r> f* 2>r f- fabs 2r> f< ;
: fsqrt ( r -- r : square root of 'r' )
  fdup f0< if fdrop [ -$2E ] literal throw then
  fdup f0= if fdrop fzero exit then
  fone
  [ $10 ] literal for aft
    f2dup fsq fswap f- fover f2* f/ f-
  then next
  fnip ;
: filog2 ( r -- u : Floating point integer logarithm )
  null
  fdup fzero f<= [ -$2E ] literal and throw
  ( norm ) nip [ $4001 ] literal - ;
: fhypot f2dup f> if fswap then ( a b -- c : hypotenuse )
  fabs 2>r fdup 2r> fswap f/ fsq f1+ fsqrt f* ;
: sins
  f2pi fnegate
  begin
    fdup f2pi f<
  while
    fdup fdup f. [char] , emit space fsincos
    fswap f. [char] , emit space f. cr
    [ $80AF $3FFE ] 2literal ( [ f2pi 50.0 f f/ ] 2literal )
    f+
  repeat fdrop ;
: agm f2dup f* fsqrt 2>r f+ f2/ 2r> fswap ; ( r1 r2 -- r1 r2 )
: fln ( r -- r : natural logarithm )
  [ $8000 $3FF7 ] 2literal ( [ 2 12 - s>f exp ] 2literal )
  fswap f/
  fone fswap
  [ $C ] literal for aft agm then next f+ fpi
  fswap f/
  [ $8516 $4004 ] 2literal ( [ 12 s>f fln2 f* ] 2literal )
  f- ;
: flnp1 fone f+ fln ; ( r -- r )
: flog2 fln fln2 f/ ; ( r -- r : base  2 logarithm )
: flog fln fln10 f/ ; ( r -- r : base 10 logarithm )
: f** fswap flog2 f* exp ; ( r1 r2 -- r : pow[r1, r2] )
: fatanh ( r1 -- r2 : atanh, -1 < r1 < 1 )
  fdup f1+ fswap fone fswap f- f/ fln f2/ ;
: facosh ( r1 -- r2 : acosh, 1 <= r1 < INF )
  fdup fsq f1- fsqrt f+ fln ;
: fasinh fdup fsq f1+ fsqrt f+ fln ; ( r -- r )
:s fatan-lo ( r -- r : fatan for r <= 1.0 only )
   fdup fsq fdup
[ $9F08 $3FFD ] 2literal f* ( Consider A = 0.07765095 )
[ $932B $BFFF ] 2literal f+ f* ( Constant B = -0.28743447 )
[ $FEC5 $4000 ] 2literal f+ f* ;s ( Constant C = Pi/4 - A - B )
:s fatan-hi finv fatan-lo fhpi fswap f- ;s ( r -- r )
: fatan ( r -- r : compute atan )
  fdup fabs fone f> if fatan-hi exit then fatan-lo ;
: fatan2 ( r1=y r2=x -- r3 )
  fdup f0> if f/ fatan exit then
  fdup f0< if
     fover f0<
     if   f/ fatan fpi f+
     else f/ fatan fpi f- then
     exit
  then
  fdrop
  fdup f0> if fdrop fhpi exit then
  fdup f0< if
   fdrop [ $C911 $C001 ] 2literal ( [ fhpi fnegate ] 2literal )
   exit then
  [ -$2E ] literal throw ;
: fasin fdup fsq fone fswap f- fsqrt f/ fatan ; ( r -- r )
: facos fasin fhpi fswap f- ; ( r -- r )
[then] ( opt.float )
opt.glossary [if]
:s .n . ;s ( n -- : display an address )
:s .pwd dup ." PWD:" .n ;s ( pwd -- pwd )
:s .nfa dup ."  NFA:" nfa .n ;s ( pwd -- pwd : print NFA addr )
:s .cfa dup ."  CFA:" cfa .n ;s ( pwd -- pwd : print CFA addr )
:s .blank ." --- " ;s ( -- : print attribute not set )
:s .immediate ( nfa -- nfa : is word an "immediate" word? )
   dup [ $40 ] literal and if ." IMM " exit then .blank ;s
:s .compile-only  ( nfa -- nfa : is word "compile-only"? )
   dup [ $20 ] literal and if ." CMP " exit then .blank ;s
:s .hidden ( nfa -- nfa : is word hidden? )
   dup [ $80 ] literal and if ." HID " exit then .blank ;s
:s =vm [ to' pause ] literal @ ;s ( pause = last defined BLT )
:s =exit [ to' pause ] literal cell+ @ ;s ( exit follows BLT )
:s rvm? dup @ =vm u<= swap cell+ @ =exit = and ;s ( cfa -- f ) 
:s cvm? ( cfa -- f )
   dup @ [ t' compile ] literal 2/ = swap cell+ rvm? and ;s
:s vm? dup rvm? swap cvm? or ;s ( cfa -- f )
:s .built-in dup cfa vm? if ." BLT " exit then .blank ;s
:s display ( pwd -- pwd : display info about single word )
  dup .pwd .nfa .cfa space .built-in nfa count 
  .immediate .compile-only .hidden
  [ $1F ] literal and type cr ;s
:s (w) begin ?dup while display @ repeat ;s ( voc -- )
:s .voc dup  ." voc: " . cr ;s ( voc -- voc )
: glossary get-order for aft .voc @ (w) then next ; ( -- )
[then]
: cold [ {boot} ] literal 2* @execute ; ( -- )

\ =============================================================

\ TODO: Version that parses next word but does not define
\ anything to save space
:m field (field) 2constant ;m

: htons dup [ 8 ] literal rshift swap [ 8 ] literal lshift + ; 
: ntohs htons ;
: htonl htons swap htons swap ;
: ntohl htonl ;

\ TODO: Raw socket on Linux instead of pcap?

\ TODO: Set netmask / hw addr, ipv6

\ create ip_addr a8c0 , fe0b ,
\ create ip_netmask ffff , 00ff ,
\ create hw_addr bd00 , 333b , 7f05 ,

\ TODO: Is this checksum correct? Does the added bit also need 
\ to have the potential carry wrapped around?
: checksum ( address count 0 -- checksum )
   -rot
   2/ 1- for
     dup >r @ ntohs um+ + r> cell+
   next
   drop ;

\ TODO: It might have been better to start structures with
\ the value of their encapsulating structure.

0
  6 field eth-dest      ( 48 bit source address )
  6 field eth-src       ( 48 bit destination address )
  2 field eth-type      ( 16 bit type )
constant #eth-frame

0
  2 field arp-hw        ( 16 bit hw type )
  2 field arp-proto     ( 16 bit protocol )
  1 field arp-hlen      (  8 bit hw address length )
  1 field arp-plen      (  8 bit protocol address length )
  2 field arp-op        ( 16 bit operation )
  6 field arp-shw       ( 48 bit sender hw address )
  4 field arp-sp        ( 32 bit sender ipv4 address )
  6 field arp-thw       ( 48 bit target hw address )
  4 field arp-tp        ( 32 bit target ipv4 address )
constant #arp-message

0
  4 field ac-ip         ( 32 bit protocol address )
  6 field ac-hw         ( 48 bit hw address )
constant #arp-cache

0
  1 field ip-vhl     (  4 bit version and 4 bit header length )
  1 field ip-tos        (  8 bit type of service )
  2 field ip-len        ( 16 bit length )
  2 field ip-id         ( 16 bit identification )
  2 field ip-frags      (  3 bit flags 13 bit fragment offset )
  1 field ip-ttl        (  8 bit time to live )
  1 field ip-proto      (  8 bit protocol number )
  2 field ip-checksum   ( 16 bit checksum )
  4 field ip-source     ( 32 bit source address )
  4 field ip-dest       ( 32 bit destination address )
constant #ip-header
: >ip #eth-frame #ip-header + ;

0
  1 field icmp-type     (  8 bits type )
  1 field icmp-code     (  8 bits code )
  2 field icmp-checksum ( 16 bits checksum )
constant #icmp-header

0
  2 field udp-source    ( 16 bit source port )
  2 field udp-dest      ( 16 bit destination port )
  2 field udp-len       ( 16 bit length )
  2 field udp-checksum  ( 16 bit checksum )
constant #udp-datagram
: >udp >ip #udp-datagram + ; ( udp payload )

0
  2 field tcp-source    ( 16 bit source port )
  2 field tcp-dest      ( 16 bit destination port )
  4 field tcp-seq       ( 32 bit sequence number )
  4 field tcp-ack       ( 32 bit acknowledgement )
  1 field tcp-offset    (  8 bit offset )
  2 field tcp-flags     ( 16 bit flags )
  1 field tcp-window    (  8 bit window size )
  2 field tcp-checksum  ( 16 bit checksum )
  2 field tcp-urgent    ( 16 bit urgent pointer )
constant #tcp-header
: #tcp >ip #tcp-header + ;

0
  1 field ntp-livnm   ( 2-bit Leap, 3-bit version, 3-bit mode )
  1 field ntp-stratum   ( Stratum [closeness to good clock] )
  1 field ntp-poll      ( Poll field, max suggested poll rate )
  1 field ntp-precision ( Precision [signed log2 seconds] )
  4 field ntp-root-delay ( Root delay )
  4 field ntp-root-dispersion ( Root dispersion )
  4 field ntp-refid     ( Reference ID )
  8 field ntp-ref-ts    ( Reference Time Stamp )
  8 field ntp-orig-ts   ( Origin Time Stamp )
  8 field ntp-rx-ts     ( RX Time Stamp )
  8 field ntp-tx-ts     ( 8-byte Transmit time stamp )
  \ There are more optional fields, of varying length, such
  \ as key ids, message digests, auth, etcetera.
constant #ntp-header

C000 constant %ethernet \ Ethernet packet address
2000 constant #ethernet \ Max ethernet packet length (bytes)


7F00 0001 2variable source-ip \ C0A8 018F 2variable source-ip
7F00 0001 2variable destination-ip
D8EF 2300 2variable ntp-ip \ 216.239.35.0, Google NTP
FFFF FFFF 2variable broadcast-ip

\ FF FF FF FF FF FF broadcast-mac

\ TODO: MAC address

029A variable source-port t' source-port >tbody t!
0800 variable destination-port t' destination-port >tbody t!

0800 constant proto-ip
0806 constant proto-arp
1 constant proto-icmp
6 constant proto-tcp
11 constant proto-udp

\ TODO: Handle IP fragmentation, or at least detect it
\ TODO: Detect too large packets on RX
\ TODO: Put all these words in their own vocabulary
\ TODO: Factor words
\ TODO: Abstract out non-portable words such as @/!

: eth-tx! [ -2 ] literal out! ; ( len -- )
: eth! eth-tx! [ -2 ] literal [@]  ;
: eth@ [ -3 ] literal [@] ;
: time [ -4 ] literal [@] [ -5 ] literal [@] ; 
: sleep [ -4 ] literal out! ;
: ud. <# #s bl hold #> type ;
: array [ 41 ] literal buffer ;
: " [char] " word count ( ccc" -- a u : temp string )
  dup >r here [ 100 ] literal + >r r@ swap cmove r> r> ;

\ : ?! ( u a l -- )
\  dup #1 = if drop c! exit then
\  dup [ 2 ] literal = if drop swap htons ! exit then
\  dup [ 4 ] literal = if drop 2! exit then
\  #-1 throw ;


\ TODO: Use this
: length? dup #ethernet u> throw ; ( u -- u)

\ TODO: Set MAC src/dst
: ethernet! ( -- )
  proto-ip htons %ethernet eth-type drop + ! ;

\ TODO: Make one for setting an ethernet frame also
: ip! ( src-ip dst-ip proto data-len -- )
  length?
  ethernet!
  [ 0040 ] literal %ethernet #eth-frame + ip-frags drop + !
  htons %ethernet #eth-frame + ip-len drop + !
  %ethernet #eth-frame + ip-proto drop + c!
  htonl %ethernet #eth-frame + ip-dest drop + 2!
  htonl %ethernet #eth-frame + ip-source drop + 2!
  [ FF ] literal %ethernet #eth-frame + ip-ttl drop + c!
  [ 45 ] literal %ethernet #eth-frame + ip-vhl drop + c!
  %ethernet #eth-frame + #ip-header #0 checksum invert htons
  %ethernet #eth-frame + ip-checksum drop + !  ;

\ UDP checksum calculation over data and IP pseudo header
: udp-check  ( length -- checksum )
  length?
  >r
  %ethernet #eth-frame + ip-source >r + r> #0 checksum
  %ethernet #eth-frame + ip-dest   >r + r> rot checksum
  proto-udp um+ +
  r@ #udp-datagram + um+ +
  %ethernet >ip + r> #udp-datagram + aligned rot checksum 
  invert ;

: udp-zero ( length -- : zero UDP + IP + Frame )
  length?
  %ethernet swap #eth-frame + #ip-header + #udp-datagram + 
  aligned #0 fill ;

: udp-fmt ( src-ip dst-ip src-port dst-port data u -- u )
  length?
  dup %ethernet swap #eth-frame + #ip-header + #udp-datagram + 
  aligned #0 fill \ Zero all packet

  %ethernet >udp + over >r swap cmove
  r@ #udp-datagram + htons %ethernet >ip + udp-len drop + !
  htons %ethernet >ip + udp-dest drop + !
  htons %ethernet >ip + udp-source drop + !

  proto-udp r@ #udp-datagram + #ip-header + ip!

  r@ udp-check htons %ethernet >ip + udp-checksum drop + !

  r> #udp-datagram + #ip-header + #eth-frame + length? ;

: address ( -- src-ip dst-ip src-port dst-port )
  source-ip 2@ destination-ip 2@ 
  source-port @ destination-port @ ;
: udp! >r >r address r> r> udp-fmt eth! ; ( data u -- f )

\ TODO: Do not trust ip-len
: ?ethernet ( -- f : is invalid ethernet packet? )
  %ethernet eth-type drop + @ ntohs proto-ip <> ?dup ?exit
  #0 ;

\ https://stackoverflow.com/questions/60550481
: fragmented?
  %ethernet #eth-frame + ip-frags drop + @ ntohs
  [ $3FFF ] literal and 0<> ;

: ?ip ( -- f : is invalid ip packet? )
  ?ethernet ?dup ?exit

  %ethernet #eth-frame + ip-vhl drop + c@ [ 45 ] literal <> 
  ?dup ?exit

  %ethernet #eth-frame + ip-checksum drop + @ ntohs ?dup if
     drop
     %ethernet #eth-frame + #ip-header #0 checksum invert htons
     0<> ?dup ?exit
  then
  #0 ;

: ?udp ( -- f : is invalid udp packet? )
  ?ip ?dup ?exit

  %ethernet #eth-frame + ip-proto drop + c@ proto-udp <> 
  ?dup ?exit

  %ethernet >ip + udp-checksum drop + @ ntohs ?dup if
\     %ethernet >ip + udp-len  drop + @ ntohs #udp-datagram -
\     udp-check ." >>>" u. u.
      drop
  then

  #0 ;

: ?icmp ( -- f )
;
: icmp@ ( -- type code rest-of-header )
;
: icmp! ( type code rest-of-header -- f )
;

: ?arp 
;
: arp@ 
;
: arp! 
;


: us? ( ip -- f : packet addressed to us? )
;

\ TODO: fragmented packet response...
\ TODO: Make sure it is a UDP packet, calculate checksums, ...
\ TODO: Insecure remote execution protocol
: udp@ ( -- src-ip dst-ip src-port dst-port data u )
  ?udp 0<> throw \ TODO: Bool instead?
  %ethernet #eth-frame + ip-source drop + 2@ ntohl
  %ethernet #eth-frame + ip-dest drop + 2@ ntohl
  %ethernet >ip + udp-source drop + @ ntohs
  %ethernet >ip + udp-dest drop + @ ntohs
  %ethernet >udp + 
  %ethernet >ip + udp-len drop + @ ntohs 
  #udp-datagram - ;

\ : bytes dup [ $FF ] literal and swap [ 8 ] rshift ;

: .ip ( ip -- print double cell ip in hex )
  base @ >r hex
  swap <# 
    # # [char] . hold
    # # [char] . hold
    # # [char] . hold
    # #
  #> type
  r> base ! ;

: .udp ( src-ip dst-ip src-port dst-port data u -- )
  2>r 2>r 2>r cr
  ." UDP:" cr 
  ." IP-SRC: " .ip cr
  ." IP-DST: " 2r> .ip cr
  ." PORT-SRC: " r> u. cr
  ." PORT-DST: " r> u. cr
  ." HEX DUMP: " 2r> dump cr ;


variable <udp>
variable <tcp>
variable <icmp>

: @udp <udp> @execute ;
: @tcp <tcp> @execute ;
: @icmp <icmp> @execute ;

: ethernet ( -- f )
  %ethernet #eth-frame + ip-vhl drop + c@ [ 45 ] literal =
  if
    %ethernet #eth-frame + ip-proto drop + c@ 
    dup proto-icmp = if drop ." ICMP" cr #-1 exit then
    dup proto-tcp = if drop ." TCP" cr #-1 exit then
        proto-udp = if udp@ .udp #-1 exit then
  then #0 ;

: sntp!
  array [ 30 ] literal #0 fill
  [ 1b ] literal array c!
  source-ip 2@ ntp-ip 2@ [ 3FF ] literal [ 7B ] literal
  array [ 30 ] literal udp-fmt eth! ;

: sntp@ ( -- time )
;

\ TODO: Make a series of tasks
\ - Read IP packets
\ - Sleep
\ - Handle User I/O
: internet
   begin
     pause
     eth@ 0> if ethernet drop then
     [ 10 ] literal sleep
     \ key? if bl or [char] q = else #0 then
     key? if 0<> else #0 then
   until ;

: zoop $" Hello, World!" count udp! ;


\ TODO: SNTP
\ 
\ - Get IP addresses of well known SNTP servers 
\ - udp-fmt, ...
\ 
\ #define DELTA (2208988800ull)
\ 
\ static inline unsigned long unpack32(unsigned char *p) {
\   assert(p);
\   unsigned long l = 0;
\   l |= ((unsigned long)p[0]) << 24;
\   l |= ((unsigned long)p[1]) << 16;
\   l |= ((unsigned long)p[2]) <<  8;
\   l |= ((unsigned long)p[3]) <<  0;
\   return l;
\ }
\ 
\   unsigned char h[48] = { 0x1b, };
\   /* we could make this stateful + non-blocking if needed */
\   const int fd = establish(server, port ? port : 123, 
\                                              SOCK_DGRAM);
\   if (fd < 0)
\     return -1;
\   if (write(fd, h, sizeof h) != sizeof h)
\     return -2;
\   if (read(fd, h, sizeof h) != sizeof h)
\     return -3;
\   if (close(fd) < 0)
\     return -4;
\   *seconds    = unpack32(&h[40]) - DELTA;
\   *fractional = unpack32(&h[44]);


\ =============================================================

t' (boot) half {boot} t!      \ Set starting Forth word
t' quit {quit} t!             \ Set initial Forth word
atlast {forth-wordlist} t!    \ Make wordlist work
{forth-wordlist} {current} t! \ Set "current" dictionary
there h t!                    \ Assign dictionary pointer
local? {user}  t!             \ Assign number of locals
primitive t@ double mkck check t! \ Set checksum over Forth
atlast {last} t!              \ Set last defined word
save-target                   \ Output target
.end                          \ Get back to normal Forth
bye                           \ Auf Wiedersehen

\ defined random 0= [if]
\ cell 2 = ?\ 13 constant #a 9  constant #b 7  constant #c
\ cell 4 = ?\ 13 constant #a 17 constant #b 5  constant #c
\ cell 8 = ?\ 12 constant #a 25 constant #b 27 constant #c
\ defined #a 0= [if] abort" Invalid Cell Size" [then]
\ 
\ variable seed 7 seed ! ( must not be zero )
\ 
\ : seed! ( x -- : set the value of the PRNG seed )
\   dup 0= if drop 7 ( zero not allowed ) then seed ! ;
\ 
\ : random ( -- x : random number )
\   seed @
\   dup #a lshift xor
\   dup #b rshift xor
\   dup #c lshift xor
\   dup seed! ;
\   (def *months* ; months of the year association list
\     '((0 . January)  (1 . February)  (2 . March) 
\       (3 . April)    (4 . May)       (5 . June) 
\       (6 . July)     (7 . August)    (8 . September)
\       (9 . October)  (10 . November) (11 . December)))
\   (def *week-days* ; days of the week association list
\     '((0 . Sunday)  (1 . Monday)  (2 . Tuesday) (3 . Wednesday)
\       (4 . Thurday) (5 . Friday)  (6 . Saturday)))
\   ; Programmers in their arrogance see how dates and times are handled and want
\   ; to simplify the calendar we use, which given this bullshit seems
\   ; reasonable. Perhaps we should just use Unix time in day to day conversation
\   ; just so I do not have to look at this code, alternatively we could all go
\   ; live under rocks.
\   (defun date (z) ; Convert Unix Time to a Date List, See <https://stackoverflow.com/questions/7960318>
\          pgn
\          (def o z)
\          (set z (div z 86400)) ; z -> Days
\          (set z (add z 719468))
\          (def era (div (if (meq z 0) z (sub z 146096)) 146097))
\          (def doe (abs (sub z (mul era 146097))))
\          (def yoe (div (add doe (negate (div doe 1460)) (div doe 36524) (negate (div doe 146096))) 365))
\          (def y (add yoe (mul era 400)))
\          (def doy (sub doe (add (mul 365 yoe) (div yoe 4) (negate (div yoe 100)))))
\          (def mp (div (add 2 (mul 5 doy)) 153))
\          (def d (sub (add 1 doy) (div (add 2 (mul mp 153)) 5)))
\          (def m (add mp (if (less mp 10) 3 -9)))
\          (list (add y (if (leq m 2) 1 0)) m d (div (mod o 86400) 3600) (div (mod o 3600) 60) (mod o 60)))
\   (defun unix (z) ; Convert Date List `(year months days hours minutes seconds)` to Unix Time
\          pgn
\          (def y (car z)) (set z (cdr z))
\          (def m (car z)) (set z (cdr z))
\          (def d (car z)) (set z (cdr z))
\          (def H (car z)) (set z (cdr z))
\          (def M (car z)) (set z (cdr z))
\          (def S (car z))
\          (def r (add S (mul M 60) (mul H 3600)))
\          (set y (sub y (if (leq m 2) 1 0)))
\          (def era (div (if (meq y 0) y (sub y 399)) 400))
\          (def yoe (abs (sub y (mul era 400))))
\          (def doy (add (div (add (mul 153 (add m (if (more m 2) -3 9))) 2) 5) d -1))
\          (def doe (add (mul yoe 365) (div yoe 4) (negate (div yoe 100)) doy))
\          (add r (mul 86400 (add (mul era 146097) doe -719468))))
\   ; https://en.wikipedia.org/wiki/Zeller%27s_congruence
\   ; https://news.ycombinator.com/item?id=11358999
\   (defun day-of-week (z)
\     pgn
\       (set year (car z)) (set z (cdr z))
\       (set month (car z)) (set z (cdr z))
\       (set day (car z)) ; Don't care about rest
\       (set day 
\         (add day
\               (if
\                 (less month 3)
\                 (add 1 (set year (sub year 1))) ; increment year but return original year
\                 (sub year 2))))
\       (mod (add
\         (div (mul 23 month) 9)
\         day
\         4
\         (div year 4)
\         (negate (div year 100))
\         (div year 400)) 7))
\   (defun day? (s)
\            pgn 
\            (def d (date s)) 
\            (cdr (assoc (day-of-week (list (car d) (cadr d) (car (cddr d)))) *week-days*)))
