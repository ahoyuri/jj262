package jj262_pkg;
    //mal schauen ob die wirklich verwendet werden
    typedef enum logic [1:0] { BASE_ZERO, BASE_SP, BASE_PTR, BASE_PC } base_sel_e;;
    typedef enum logic [1:0] { OFF_ZERO, OFF_DISP, OFF_IMM } off_sel_e;
    typedef enum logic [1:0] { AKK_ALU, AKK_MEM, AKK_PTR, AKK_IMM } akk_src_e;

    typedef enum logic [3:0] { 
        OP_ADD = 4'h0,
        OP_SUB = 4'h1,
        OP_SHL = 4'h2,
        OP_SHR = 4'h3,
        OP_AND = 4'h4,
        OP_OR = 4'h5,
        OP_NOT = 4'h6,
        OP_XOR = 4'h7,
        OP_ADC = 4'h8,
        OP_SUC = 4'h9
     } alu_op_e;

    typedef struct packed {
        logic   akk_we;     //Register Writes
        logic   ptr_we;
        logic   sp_we;
        logic   pc_we;
        logic   flag_we;
        akk_src_e   akk_src;
        base_sel_e  mar_base;   //Adressrechenwerk
        off_sel_e   mar_off;
        logic   mar_we;
        logic   mem_re;     //Speicher
        logic   mem_we;
        logic mem_byte;
        alu_op_e    alu_op;
        logic   done;       //Ablauf
    } ctrl_s;

    //16bit Befehle
    //[15:8] opcode_e [7:0] XY (Daten)
    typedef enum logic [7:0] { 
        OP_NOP      =   8'h0,
        //move
        //Alle Move befehle ohne IMM, verwenden XY um zum source dazu addiert zu werden
        OP_MILAK    =   8'h1,   //move immediate low to akkumulator, löscht High-Byte
        OP_MIHAK    =   8'h2,   //move immediate high to akkumulator
        OP_MAPT     =   8'h3,   //move akkumulator to pointer, PTR = AKK + XY
        OP_MPAK     =   8'h4,   //move pointer to akkumulator, AKK = PTR + XY
        OP_MILPT    =   8'h5,   //move immediate low to pointer, löscht High-Byte
        OP_MIHPT    =   8'h6,   //move immediate high to pointer
        OP_MILSP    =   8'h7,   //move immediate low to stackpointer, löscht High-Byte
        OP_MIHSP    =   8'h8,   //move immediate high to stackpointer
        OP_MASP     =   8'h9,   //move akkumulator to stackpointer
        OP_MPSP     =   8'hA,   //move pointer to stackpointer
        OP_MSAK     =   8'hB,   //move stackpointer to akkumulator
        OP_MSPT     =   8'hC,
        //frame befehle
        OP_ADDSP    =   8'hD,   //SP = SP + XY
        OP_SUBSP    =   8'hE,   //SP = SP - XY
        //store
        OP_SAPT     =   8'hF,   //store akkumator in &ptr, PTR[XY] = AKK
        OP_SPPT     =   8'h10,   //store pointer in &ptr, PTR[XY] = ptr
        OP_SASP     =   8'h11,   //store akkumaltor in &sp, sp[XY] = AKK
        OP_SPSP     =   8'h12,   //store pointer in &sp, sp[XY] = PTR
        //load 
        OP_LPAK     =   8'h13,   //load &Pointer into AKK, AKK = PTR[XY]
        OP_LPPT     =   8'h14,   //load &Pointer into Pointer, PTR = PTR[XY];
        OP_LAAK     =   8'h15,  //load &Akumulator into Akkumulator, AKK = AKK[XY]
        OP_LAPT     =   8'h16,  //load &Akkumulator into Pointer, PTR = AKK[XY]
        OP_LSAK     =   8'h17,  //load &SP into Akk, AKK = SP[XY]
        OP_LSPT     =   8'h18,  //load &SP into PTR, PTR = SP[XY]
        //MV memory to memory befehle [XY] = [XY]
        OP_MVAP     =   8'h19,  //PTR[XY] = AKK[XY]
        OP_MVPA     =   8'h1A,  //AKK[XY] = PTR[XY]
        //ptr funktionen
        OP_INCPT    =   8'h1B,  //PTR = PTR + XY
        OP_DECPT    =   8'h1C,  //PTR = PTR - XY

        
        OP_ALU      =   8'h1D,  //ALU controlle über XY (!noch wo anderes codieren)    
        //IMM bekommt eigene befehle:
        OP_ADDI     =   8'h1E,  // AKK = AKK + zero_ext(XY)
        OP_SUBI     =   8'h1F,
        OP_ANDI     =   8'h20,
        OP_ORI      =   8'h21,
        OP_XORI     =   8'h22,
        OP_SHLI     =   8'h23,
        OP_SHRI     =   8'h24,
        OP_ASRI     =   8'h25,
        OP_CMPI     =   8'h26,  // SUB ohne Writeback
        OP_TSTI     =   8'h27,  // AND ohne Writeback
        OP_CMPS     =   8'h28,  //vergleich AKK mit SP[XY]
        
        OP_JMP      =   8'h29,  //Spünge, codierung in XY (!noch wo anders codieren)
        CALL
        ICALL
        RET 
        INT 
        RETI
     } opcode_e;
endpackage