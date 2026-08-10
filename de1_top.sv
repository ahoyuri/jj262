module de1_top (
	input logic		CLOCK_50,
	input logic [3:0] KEY,	//Buttons (active low)
	input logic [9:0] SW,	//Switches
	output logic [9:0] LEDR,	//RED LEDs
	output logic [6:0] HEX0	// 7-Segment Display
);

	assign LEDR = SW;	// Switches stuern LEDR
endmodule