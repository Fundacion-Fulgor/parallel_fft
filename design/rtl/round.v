// ----------------------------------------------------------------------------------------------------------------------------
// Module Name: round.v
// ----------------------------------------------------------------------------------------------------------------------------
// Description:
//
// ----------------------------------------------------------------------------------------------------------------------------
// Revision History:
//      Date:         2026-01-03
//      Author:       A. Lema
//      Organization: Fundación Fulgor
// ----------------------------------------------------------------------------------------------------------------------------

module round#(
    parameter	NB_INP  = 32,
    parameter	NBF_INP	= 30,
    parameter	NB_OUT	= 16,
    parameter	NBF_OUT	= 15,
    parameter   RND_MD  =  0  // 0: SAT-TRUNC, 1: SAT-ROUND
)
(
    input  signed [NB_INP-1:0] i_data,
    output signed [NB_OUT-1:0] o_data
);

///////////////////////////////////////////////////////////////////////////////
// WIRE AND REGISTER
///////////////////////////////////////////////////////////////////////////////

localparam SIGNED = (NB_INP - NBF_INP) - (NB_OUT - NBF_OUT) + 1;
localparam BITS_DIS = NBF_INP - NBF_OUT;

wire signed [NB_INP-1:0] w_data;
wire signed [NB_OUT-1:0] w_rnd;

///////////////////////////////////////////////////////////////////////////////
// COMBINATIONAL LOGIC
///////////////////////////////////////////////////////////////////////////////

assign w_data = i_data;

generate
    case (RND_MD)
        0: begin: gen_trunc
            assign w_rnd = (~|w_data[NB_INP-1 -:SIGNED] || &w_data[NB_INP-1 -:SIGNED]) ?
                              w_data[(NB_INP-SIGNED)-:NB_OUT] :
                             (w_data[NB_INP-1]) ? {1'b1,{NB_OUT-1{1'b0}}} : {1'b0,{NB_OUT-1{1'b1}}};      
        end
        1: begin : gen_round
            wire [NB_INP:0] data_plus_round;

            if (BITS_DIS > 0) begin : gen_add_round
                assign data_plus_round = {i_data[NB_INP-1], i_data} + (1'b1 << (BITS_DIS - 1));
            end else begin : gen_no_round
                assign data_plus_round = {i_data[NB_INP-1], i_data};
            end
            assign w_rnd = (~|data_plus_round[NB_INP -: SIGNED+1] || &data_plus_round[NB_INP -: SIGNED+1]) ?
                              data_plus_round[(NB_INP-SIGNED+1) -: NB_OUT] :
                              (data_plus_round[NB_INP]) ? {1'b1,{NB_OUT-1{1'b0}}} : {1'b0,{NB_OUT-1{1'b1}}};
            end

            default: begin : gen_default
                assign w_rnd = {NB_OUT{1'b0}};
            end 
    endcase
endgenerate

assign o_data = w_rnd;

endmodule
