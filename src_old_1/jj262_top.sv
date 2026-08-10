import jj262_pkg::*;

module jj262_top (
	input logic		CLOCK_50,
	input logic [3:0] KEY,	//Buttons (active low)
	input logic [9:0] SW,	//Switches
    //Joystick/adc/pins with cap
    //64x64LED 
	output logic [9:0] LEDR,	//RED LEDs
	output logic [6:0] HEX0,	// 7-Segment Display
    output logic [6:0] HEX1,
    output logic [6:0] HEX2
);
    logic clk;
    assign clk = CLOCK_50;
    logic rst_meta, rst;
    //sync
    always_ff @(posedge CLOCK_50) begin
        rst_meta <= ~KEY[0];
        rst      <= rst_meta;
    end

    logic [4:0] flags;
    ctrl_s ctrl;

    cu_main cu(
        .clk (clk),
        .rst(rst),
        .op(iw[15:8]),
        .f_z(flags[FLG_Z]), 
        .f_c(flags[FLG_C]), 
        .f_s(flags[FLG_S]), 
        .f_v(flags[FLG_V]),
        .ctrl(ctrl)
    );

    logic [15:0] bus_result;
    logic [15:0] abus_result;
    datapath path(
        .clk(clk),
        .rst(rst),
        .ctrl(ctrl),
        .xy(iw[7:0]),               // IW[7:0]
        .mem_q(mem_q),              // RAM-Lesewert  (BUS_RMEM)
        .pc(pc),                    // PC-Wert       (BUS_PC)
        .bus_result(bus_result),    // -> mem_wdata UND -> PC-Register (bei pc_we)
        .abus_result(abus_result),  // -> RAM-Adressport
        .flags(flags)               // -> cu (Sprungbedingungen)
    );

    // --- Signale, die die MMU braucht/liefert ---
    logic [15:0] mem_q;
    logic [7:0]  irq_vector;
    logic        irq_pending;

    mmu u_mmu (
        .clk       (CLOCK_50),
        .rst       (rst),

        // von der CPU
        .abus      (abus_result),      // aus datapath
        .wdata     (bus_result),       // aus datapath
        .mem_re    (ctrl.mem_re),
        .mem_we    (ctrl.mem_we),
        .mem_byte  (ctrl.mem_byte),
        .mem_bsext (ctrl.mem_bsext),

        // zur CPU
        .mem_q       (mem_q),          // -> datapath (BUS_RMEM)
        .irq_vector  (irq_vector),     // -> Injector
        .irq_pending (irq_pending),    // -> Injector

        // Board
        .SW   (SW),
        .KEY  (KEY),
        .LEDR (LEDR),
        .HEX0 (HEX0), .HEX1 (HEX1), .HEX2 (HEX2), .HEX3 (HEX3)
    );

    logic [15:0] pc, iw;

    op_loader #(.DEPTH(4096)) u_loader (
        .clk         (CLOCK_50),
        .rst         (rst),

        // CPU
        .done        (ctrl.done),
        .pc_we       (ctrl.pc_we),
        .pc_load     (bus_result),
        .pc          (pc),              // -> datapath (BUS_PC)
        .iw          (iw),              // -> cu (iw[15:8]), datapath (iw[7:0])

        // Interrupt
        .irq_pending (irq_pending),     // von mmu
        .irq_vector  (irq_vector),      // von mmu
        .irq_enabled (flags[FLG_IE]),

        // ROM-Schreibport (Tape) — noch nicht angeschlossen
        .rom_wr_addr (16'h0000),
        .rom_wr_data (16'h0000),
        .rom_wr_en   (1'b0)
    );

endmodule