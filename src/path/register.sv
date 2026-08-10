import jj262_pkg::*;


module reg_en #(
    parameter int W = 16
)(
    input  logic         clk,
    input  logic         rst,
    input  logic         we,
    input  logic [W-1:0] d,
    output logic [W-1:0] q
);
    always_ff @(posedge clk or posedge rst)
        if (rst)     q <= '0;
        else if (we) q <= d;
endmodule

module flag_reg (
    input  logic         clk,
    input  logic         rst,
    input  ctrl_s        ctrl,
    input logic [FLG_W-1:0] flg_din, //vom datenbus //bus_result[FLG_W-1:0]
    input logic         alu_z, alu_c, alu_s, alu_v,
    output logic [FLG_W-1:0]  flags
);
    always_ff @(posedge clk or posedge rst)
        if (rst)
            flags <= '0;                    // IE = 0 nach Reset
        else if (ctrl.flg_we)
            flags <= flg_din;
        else begin
            if (ctrl.flags_we) begin
                flags[FLG_Z] <= alu_z;
                flags[FLG_C] <= alu_c;
                flags[FLG_S] <= alu_s;
                flags[FLG_V] <= alu_v;
            end
            if (ctrl.irq_set) flags[FLG_IE] <= 1'b1;
            if (ctrl.irq_clr) flags[FLG_IE] <= 1'b0;
        end
endmodule

module pc_reg (
    input  logic        clk,
    input  logic        rst,
    input  logic        load,      // ctrl.pc_we — Sprungziel
    input  logic [15:0] load_val,  // bus_result
    input  logic        advance,   // ctrl.done — weiterzählen
    output logic [15:0] pc,
    output logic [15:0] pc_next    // kombinatorisch -> ROM-Adressport
);
    always_comb begin
        if      (rst)     pc_next = '0;        // waehrend Reset auf 0 zeigen,
                                               // sonst holt das ROM schon mem[1]
        else if (load)    pc_next = load_val;
        else if (advance) pc_next = pc + 16'd1;
        else              pc_next = pc;
    end

    always_ff @(posedge clk or posedge rst)
        if (rst) pc <= '0;
        else     pc <= pc_next;
endmodule