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
    output logic [6:0] HEX2,
    output logic [6:0] HEX3,
    output logic [2:0]  HUB_RGB0, HUB_RGB1,
    output logic [4:0]  HUB_ADDR,
    output logic        HUB_CLK, HUB_LAT, HUB_OE
    
);
    // ------------------------------------------------------------------
    //  Takt: 50 MHz halbieren -> 25 MHz.
    //  Bei 50 MHz schliesst das Timing NICHT (Slack ca. -14 ns).
    //  clk_div braucht in der SDC einen generated clock:
    //    create_generated_clock -name clk_div -source [get_ports CLOCK_50] \
    //        -divide_by 2 [get_registers {*clk_div*}]
    //  ALLE Module an clk — nur Teiler und Reset-Sync an CLOCK_50.
    // ------------------------------------------------------------------
    logic clk_div = 1'b0;
    always_ff @(posedge CLOCK_50)
        clk_div <= ~clk_div;

    logic clk;
    assign clk = clk_div;

    logic rst_meta, rst;
    always_ff @(posedge clk) begin
        rst_meta <= SW[9];      // statt ~KEY[0]
        rst      <= rst_meta;
    end



    // --- alle internen Signale, VOR den Instanzen ---
    logic [FLG_W-1:0] flags;
    ctrl_s            ctrl;
    logic [15:0]      pc, iw;
    logic             injected;        // HW-IRQ verdraengt einen Befehl
    logic [15:0]      rom_wr_addr, rom_wr_data;
    logic             rom_wr_en;        // HW-IRQ verdraengt einen Befehl
    logic [15:0]      bus_result, abus_result;
    logic [15:0]      mem_q;
    logic [7:0]       irq_vector;
    logic             irq_pending;

    cu_main cu(
        .clk (clk),
        .rst(rst),
        .op(iw[15:8]),
        .injected(injected),
        .f_z(flags[FLG_Z]), 
        .f_c(flags[FLG_C]), 
        .f_s(flags[FLG_S]), 
        .f_v(flags[FLG_V]),
        .ctrl(ctrl)
    );

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

    mmu u_mmu (
        .clk       (clk),
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
        .HEX0 (HEX0), .HEX1 (HEX1), .HEX2 (HEX2), .HEX3 (HEX3),
        .HUB_RGB0(HUB_RGB0), .HUB_RGB1(HUB_RGB1), .HUB_ADDR(HUB_ADDR),
        .HUB_CLK(HUB_CLK), .HUB_LAT(HUB_LAT), .HUB_OE(HUB_OE),
        .TAPE_IN(SW[4]),
        .rom_wr_addr(rom_wr_addr), .rom_wr_data(rom_wr_data), .rom_wr_en(rom_wr_en)
    );


    op_loader #(.DEPTH(4096)) u_loader (
        .clk         (clk),
        .rst         (rst),

        // CPU
        .done        (ctrl.done),
        .halt        (ctrl.halt),
        .pc_we       (ctrl.pc_we),
        .pc_load     (bus_result),
        .pc          (pc),              // -> datapath (BUS_PC)
        .iw          (iw),              // -> cu (iw[15:8]), datapath (iw[7:0])
        .injected    (injected),        // -> cu_decode: Ruecksprungadresse

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