`timescale 1ns/1ps
module tb;
  logic CLOCK_50=0; logic [3:0] KEY=4'b1111; logic [9:0] SW=0;
  logic [9:0] LEDR; logic [6:0] HEX0,HEX1,HEX2,HEX3;
  jj262_top dut(.CLOCK_50(CLOCK_50),.KEY(KEY),.SW(SW),.LEDR(LEDR),
                .HEX0(HEX0),.HEX1(HEX1),.HEX2(HEX2),.HEX3(HEX3));
  always #10 CLOCK_50=~CLOCK_50;
  initial begin
    KEY[0]=0; repeat(4) @(posedge CLOCK_50); KEY[0]=1;
    $display(" pc    iw    akk   ptr   Z C S V  done ph");
    repeat(20) begin
      @(posedge CLOCK_50); #1
      $display("%04h  %04h  %04h  %04h  %b %b %b %b   %b   %0d",
        dut.pc, dut.iw, dut.path.akk, dut.path.ptr,
        dut.flags[0],dut.flags[1],dut.flags[2],dut.flags[3],
        dut.ctrl.done, dut.cu.phase);
    end
    $finish;
  end
endmodule
