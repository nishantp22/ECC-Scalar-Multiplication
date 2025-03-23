////////////////////////////////////////////  Finite Field Multiplier ///////////////////////////////////////////////////
module ffm (
    input  wire clk,
    input  wire rst,
    input  wire start,    
    input  wire [254:0] a,      // 255-bit input a
    input  wire [254:0] b,      // 255-bit input b
    output reg  [254:0] result, // 255-bit output (a*b mod P)
    output reg  valid           // Indicates when result is valid
);

    parameter [254:0] P = {1'b1, 255'b0} - 19;   // P = 2^255 - 19

    // Widen inputs to 256 bits (MSB zero-padded)
    wire [263:0] a_ext = {9'b0, a};             //extending to 264 as we are performing 24*16
    wire [255:0] b_ext = {1'b0, b};

    // Multiplier signals
    reg start_mult;
    wire mult_valid;
    wire [519:0] product;


    // Instantiate the sequential 256x256 multiplier
    mult256_seq multiplier_inst (clk,rst,start_mult,a_ext,b_ext,mult_valid,product);

    // Partial reduction
    wire [84:0] C0 = product[84:0];
    wire [84:0] C1 = product[169:85];
    wire [84:0] C2 = product[254:170];
    wire [84:0] C3 = product[339:255];
    wire [84:0] C4 = product[424:340];
    wire [84:0] C5 = product[509:425];

    wire [89:0] C3_ext = {5'b0, C3};
    wire [89:0] C4_ext = {5'b0, C4};
    wire [89:0] C5_ext = {5'b0, C5};

    wire [89:0] C3_19 = (C3_ext << 4) + (C3_ext << 1) + C3_ext;
    wire [89:0] C4_19 = (C4_ext << 4) + (C4_ext << 1) + C4_ext;
    wire [89:0] C5_19 = (C5_ext << 4) + (C5_ext << 1) + C5_ext;

    wire [89:0] S0 = {5'b0, C0} + C3_19;
    wire [89:0] S1 = {5'b0, C1} + C4_19;
    wire [89:0] S2 = {5'b0, C2} + C5_19;

    wire [259:0] initial_sum = {{(260-90){1'b0}}, S0} + {S1, 85'b0} + {S2, 170'b0};
    wire [259:0] P_ext = {5'b0, P};

    // FSM for controlling multiplication and modular reduction
    reg [2:0] state;
    localparam IDLE = 3'd0, WAIT_MULT = 3'd1, REDUCE = 3'd2, DONE = 3'd3, OUT = 3'd4;

    reg [259:0] temp;

    always @(posedge clk or posedge rst) begin
    if (rst) begin
        state      <= IDLE;
        start_mult <= 0;
        temp       <= 0;
        result     <= 0;
        valid      <= 0;
    end else begin
        case (state)
            IDLE: begin
                valid      <= 0;
                if (start) begin  // Only trigger multiplication if start is asserted
                    start_mult <= 1;  
                    state      <= WAIT_MULT;
                end else begin
                    start_mult <= 0; // Remain idle if start is not asserted
                end
            end

            WAIT_MULT: begin
                start_mult <= 0; // Ensure start is pulsed
                if (mult_valid) begin
                    temp  <= initial_sum;
                    state <= REDUCE;
                end
            end

            REDUCE: begin
                if (temp >= P_ext)
                    temp <= temp - P_ext;
                else
                    state <= OUT;
            end

            OUT: begin
                result <= temp[254:0];  // Final reduction
                valid  <= 1;
                state  <= IDLE;
            end
        endcase
    end
end

endmodule


