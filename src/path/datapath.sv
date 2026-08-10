import jj262_pkg::*;

module datapath (
    input  logic              clk,
    input  logic              rst,
    input  ctrl_s             ctrl,
    input  logic [7:0]        xy,          // IW[7:0]
    input  logic [15:0]       mem_q,       // RAM-Lesewert  (BUS_RMEM)
    input  logic [15:0]       pc,          // PC-Wert       (BUS_PC)
    output logic [15:0]       bus_result,  // -> mem_wdata UND -> PC-Register (bei pc_we)
    output logic [15:0]       abus_result, // -> RAM-Adressport
    output logic [FLG_W-1:0]  flags        // -> cu (Sprungbedingungen)
);

    logic [15:0] akk, ptr, sp;
    logic [15:0] src_val, off_val, stage_a, alu_y;

    reg_en #(.W(16)) u_akk (
        .clk(clk), .rst(rst),
        .we (ctrl.akk_we),
        .d (bus_result),
        .q (akk)
    );
    reg_en #(.W(16)) u_ptr (
        .clk(clk), .rst(rst),
        .we (ctrl.ptr_we),
        .d (bus_result),
        .q (ptr)
    );
    //SP etwas schwerer
    logic [15:0] sp_d;
    logic sp_we_any;
    assign sp_d = ctrl.sp_abus_we ? abus_result : bus_result;
    assign sp_we_any = ctrl.sp_we | ctrl.sp_abus_we;

    reg_en #(.W(16)) u_sp (
        .clk(clk), .rst(rst),
        .we (sp_we_any),
        .d (sp_d),
        .q (sp)
    );

    //flags (eigener bauplan)
    logic alu_z, alu_c, alu_s, alu_v;
    flag_reg u_flags (
        .clk(clk), .rst(rst),
        .ctrl(ctrl),
        .flg_din(bus_result[FLG_W-1:0]),
        .alu_z(alu_z), .alu_c(alu_c), .alu_s(alu_s), .alu_v(alu_v),
        .flags(flags)
    );


    // Stufe A: Quelle + Offset (bzw. IMM_HIGH Konkat.)
    always_comb begin
        unique case (ctrl.bus_src)
            BUS_ZERO:   src_val = '0;
            BUS_AKK:    src_val = akk;
            BUS_PTR:    src_val = ptr;
            BUS_SP:     src_val = sp;
            BUS_PC:     src_val = pc;
            BUS_RMEM:   src_val = mem_q;
            BUS_FLG:    src_val = {{(16-FLG_W){1'b0}}, flags};
            default:    src_val = '0;
        endcase
        unique case (ctrl.bus_off)
            OFF_ZERO:   off_val = '0;
            OFF_ZDISP:  off_val = {8'b0, xy};
            OFF_SDISP:  off_val = {{8{xy[7]}}, xy};
            OFF_TWO:    off_val = 16'd2;
            OFF_ONE:    off_val = 16'd1;
            default:    off_val = '0;
        endcase
        stage_a = (ctrl.bus_off == OFF_IMM_HIGH) ? 
            {xy, src_val[7:0]} :
            (ctrl.bus_addsub == OFF_S_SUB) ?
            (src_val - off_val) : (src_val + off_val);
    end

    // Stufe B: Route
    alu u_alu (
        .op  (ctrl.alu_op),
        .a   (akk),           // Operand A fest = AKK
        .b   (stage_a),       // Operand B = Ergebnis Stufe A
        .cin (flags[FLG_C]),  // für ADC/SUC/RCL/RCR
        .y   (alu_y),
        .z   (alu_z),
        .c   (alu_c),
        .s   (alu_s),
        .v   (alu_v)
    );
    assign bus_result = (ctrl.route == ROUTE_ALU) ?
        (alu_y) : stage_a;



    // Adressbus: abus_src + Offset -> M4K-Adressport
    logic [15:0] abus_src_val, abus_off_val;
    always_comb begin
        unique case (ctrl.abus_src)
            ABUS_AKK: abus_src_val = akk;
            ABUS_PTR: abus_src_val = ptr;
            ABUS_SP:  abus_src_val = sp;
            ABUS_PC:  abus_src_val = pc;
            default:  abus_src_val = '0;
        endcase
        unique case (ctrl.abus_off)
            OFF_ZERO:  abus_off_val = '0;
            OFF_ZDISP: abus_off_val = {8'b0, xy};
            OFF_SDISP: abus_off_val = {{8{xy[7]}}, xy};
            OFF_TWO:   abus_off_val = 16'd2;
            OFF_ONE:   abus_off_val = 16'd1;
            default:   abus_off_val = '0;
        endcase
        abus_result = (ctrl.abus_addsub == OFF_S_SUB)
                    ? (abus_src_val - abus_off_val)
                    : (abus_src_val + abus_off_val);
    end
endmodule