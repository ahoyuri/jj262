import jj262_pkg::*;


module cu_decode (
    input opcode_e op,
    input logic phase,
    output ctrl_s   ctrl
);
    always_comb begin
        ctrl = '0;
        ctrl.done = 1'b1;   //Default: einzyklisch. nur bei Ausnahmen setzen done = 0
        if (f_is_misc(op)) begin
            //default
            ctrl.bus_dst  = DST_NONE;
            ctrl.bus_off = OFF_ZDISP;
            ctrl.bus_addsub = OFF_S_ADD;
            ctrl.route = ROUTE_DIRECT;
            unique case (f_misc_op(op))
                MOP_NOP:;               // nichts
                //Immediate -> register
                MOP_MILAK: begin
                    ctrl.bus_src = BUS_ZERO;
                    ctrl.bus_dst = DST_AKK;
                end
                MOP_MIHAK: begin
                    ctrl.bus_src = BUS_AKK;
                    ctrl.bus_off = OFF_IMM_HIGH;
                    ctrl.bus_dst = DST_AKK;
                end
                MOP_MILPT: begin
                    ctrl.bus_src = BUS_ZERO;
                    ctrl.bus_dst = DST_PTR;
                end
                MOP_MIHPT: begin
                    ctrl.bus_src = BUS_PTR;
                    ctrl.bus_off = OFF_IMM_HIGH;
                    ctrl.bus_dst = DST_PTR;
                end
                MOP_MILSP: begin
                    ctrl.bus_src = BUS_ZERO;
                    ctrl.bus_dst = DST_SP;
                end
                MOP_MIHSP: begin
                    ctrl.bus_src = BUS_SP;
                    ctrl.bus_off = OFF_IMM_HIGH;
                    ctrl.bus_dst = DST_SP;
                end
                // Register -> Register
                MOP_MAPT: begin
                    ctrl.bus_src = BUS_AKK;
                    ctrl.bus_dst = DST_PTR;
                end
                MOP_MPAK: begin
                    ctrl.bus_src = BUS_PTR;
                    ctrl.bus_dst = DST_AKK;
                end
                MOP_MASP: begin
                    ctrl.bus_src = BUS_AKK;
                    ctrl.bus_dst = DST_SP;
                end
                MOP_MPSP: begin
                    ctrl.bus_src = BUS_PTR;
                    ctrl.bus_dst = DST_SP;
                end
                MOP_MSAK: begin
                    ctrl.bus_src = BUS_SP;
                    ctrl.bus_dst = DST_AKK;
                end
                MOP_MSPT: begin
                    ctrl.bus_src = BUS_SP;
                    ctrl.bus_dst = DST_PTR;
                end
                // Frame
                MOP_ADDSP: begin
                    ctrl.bus_src = BUS_SP;
                    ctrl.bus_dst = DST_SP;
                end
                MOP_SUBSP: begin
                    ctrl.bus_src = BUS_SP;
                    ctrl.bus_addsub = OFF_S_SUB;
                    ctrl.bus_dst = DST_SP;
                end
                // PTR Arithmetik
                MOP_INCPT: begin
                    ctrl.bus_src = BUS_PTR;
                    ctrl.bus_dst = DST_PTR;
                end
                MOP_DECPT: begin
                    ctrl.bus_src = BUS_SP;
                    ctrl.bus_addsub = OFF_S_SUB;
                    ctrl.bus_dst = DST_SP;
                end
                // Wort loads ziel = [basis + XY]
                MOP_LPAK: begin
                    if (phase == 0) begin
                        ctrl.abus_src = ABUS_PTR;
                        ctrl.abus_off = OFF_ZDISP;
                        ctrl.mem_re = 1'b1;
                        ctrl.done = 1'b0;    
                    end else begin
                        ctrl.bus_src = BUS_RMEM;
                        ctrl.bus_dst = DST_AKK;
                    end
                end
                MOP_LPPT: begin
                    if (phase == 0) begin
                        ctrl.abus_src = ABUS_PTR;
                        ctrl.abus_off = OFF_ZDISP;
                        ctrl.mem_re = 1'b1;
                        ctrl.done = 1'b0;    
                    end else begin
                        ctrl.bus_src = BUS_RMEM;
                        ctrl.bus_dst = DST_PTR;
                    end
                end
                MOP_LAAK: begin
                    if (phase == 0) begin
                        ctrl.abus_src = ABUS_AKK;
                        ctrl.abus_off = OFF_ZDISP;
                        ctrl.mem_re = 1'b1;
                        ctrl.done = 1'b0;    
                    end else begin
                        ctrl.bus_src = BUS_RMEM;
                        ctrl.bus_dst = DST_AKK;
                    end
                end
                MOP_LAPT: begin
                    if (phase == 0) begin
                        ctrl.abus_src = ABUS_AKK;
                        ctrl.abus_off = OFF_ZDISP;
                        ctrl.mem_re = 1'b1;
                        ctrl.done = 1'b0;    
                    end else begin
                        ctrl.bus_src = BUS_RMEM;
                        ctrl.bus_dst = DST_PTR;
                    end
                end
                MOP_LSAK: begin
                    if (phase == 0) begin
                        ctrl.abus_src = ABUS_SP;
                        ctrl.abus_off = OFF_ZDISP;
                        ctrl.mem_re = 1'b1;
                        ctrl.done = 1'b0;    
                    end else begin
                        ctrl.bus_src = BUS_RMEM;
                        ctrl.bus_dst = DST_AKK;
                    end
                end
                MOP_LSPT: begin
                    if (phase == 0) begin
                        ctrl.abus_src = ABUS_SP;
                        ctrl.abus_off = OFF_ZDISP;
                        ctrl.mem_re = 1'b1;
                        ctrl.done = 1'b0;    
                    end else begin
                        ctrl.bus_src = BUS_RMEM;
                        ctrl.bus_dst = DST_PTR;
                    end
                end


                default:;
            endcase
        end
        else if (f_is_alu(op)) begin
        end
        else if (f_is_jmp(op)) begin
        end

        // aktivierung der register in die geschrieben wird
        ctrl.akk_we = (ctrl.bus_dst == DST_AKK);
        ctrl.ptr_we = (ctrl.bus_dst == DST_PTR);
        ctrl.sp_we  = (ctrl.bus_dst == DST_SP);
        ctrl.pc_we  = (ctrl.bus_dst == DST_PC);
        ctrl.mem_we = (ctrl.bus_dst == DST_WMEM);

    end

endmodule