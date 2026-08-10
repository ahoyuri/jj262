import jj262_pkg::*;

module cu_main (
    input  logic       clk,
    input  logic       rst,
    input  logic [7:0] op,
    input  logic       f_z, f_c, f_s, f_v,
    output ctrl_s      ctrl              // <- muss raus zu den anderen Modulen!
);
    logic [1:0] phase;

    cu_counter u_counter (
        .clk   (clk),
        .rst   (rst),
        .done  (ctrl.done),
        .phase (phase)
    );

    cu_decode u_decode (
        .op    (op),
        .phase (phase),
        .f_z   (f_z),
        .f_c   (f_c),
        .f_s   (f_s),
        .f_v   (f_v),
        .ctrl  (ctrl)
    );
endmodule

module cu_counter (
    input  logic       clk,
    input  logic       rst,
    input  logic       done,
    output logic [1:0] phase
);
    always_ff @(posedge clk or posedge rst)
        if (rst)
            phase <= '0;
        else if (done)          // synchron: zur Flanke gesampelt
            phase <= '0;
        else
            phase <= phase + 2'd1;
endmodule