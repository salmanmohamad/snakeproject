vlib work

vlog -timescale 1ns/1ns part2.v

vsim test2

log {/*}
add wave {/*}
add wave {/test2/d0/*}
add wave {/test2/d0/fs0/*}
add wave {/test2/d0/d2b2/*}
add wave {/test2/d0/f0/*}
add wave {/test2/c0/*}

#input clk,
#input resetn,
#input w,
#input a,
#input s,
#input d,
#input space,
#output [7:0] x,
#output [6:0] y,
#output [2:0] colour,
#output writeEn

force {clk} 0 0, 1 10 -r 20
force {resetn} 0 0, 1 80

force {space} 0 0, 1 100, 0 120

run 2020ns