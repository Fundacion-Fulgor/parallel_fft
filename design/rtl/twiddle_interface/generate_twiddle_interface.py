import numpy as np
from fxpmath import Fxp

NB_DATA = 8       
NBF_DATA = 7      
NUM_SAMPLES = 8   
FFT_SIZE = 32    

FXP_CONFIG = {
    'signed': True,
    'n_word': NB_DATA,
    'n_frac': NBF_DATA,
    'overflow': 'saturate',
    'rounding': 'floor'
}

def to_fxp(value):
    return Fxp(value, **FXP_CONFIG)

def get_twiddle_bin_str(k, n, fft_size, inverse=False):
    angle = -2 * np.pi * k * n / fft_size
    complex_val = np.exp(1j * angle)
    if inverse:
        complex_val = complex_val.conjugate()
    re_fxp = to_fxp(complex_val.real)
    im_fxp = to_fxp(complex_val.imag)
    return re_fxp.bin() + im_fxp.bin()

def generate_mux_logic(values_list, signal_name, width):
    lines = []
    lines.append(f"assign {signal_name} = ")
    for i, val in enumerate(values_list):
        terminator = ":" 
        condition = f"(cnt_q == 3'd{i})"
        lines.append(f"        {condition} ? {width}'b{val} {terminator}")
    lines.append(f"        {width}'d0;") 
    return "\n".join(lines)

def generate_rtl():
    filename = "twiddle_interface.v"
    width = 2 * NB_DATA
    vals_w1_fwd = []
    vals_w2_fwd = []
    vals_w3_fwd = []
    vals_w1_inv = []
    vals_w2_inv = []
    vals_w3_inv = []

    for n in range(NUM_SAMPLES):
        vals_w1_fwd.append(get_twiddle_bin_str(1, n, FFT_SIZE, False))
        vals_w2_fwd.append(get_twiddle_bin_str(2, n, FFT_SIZE, False))
        vals_w3_fwd.append(get_twiddle_bin_str(3, n, FFT_SIZE, False))
        
        vals_w1_inv.append(get_twiddle_bin_str(1, n, FFT_SIZE, True))
        vals_w2_inv.append(get_twiddle_bin_str(2, n, FFT_SIZE, True))
        vals_w3_inv.append(get_twiddle_bin_str(3, n, FFT_SIZE, True))

    block_w1_fwd = generate_mux_logic(vals_w1_fwd, "val_w1_fwd", width)
    block_w2_fwd = generate_mux_logic(vals_w2_fwd, "val_w2_fwd", width)
    block_w3_fwd = generate_mux_logic(vals_w3_fwd, "val_w3_fwd", width)
    
    block_w1_inv = generate_mux_logic(vals_w1_inv, "val_w1_inv", width)
    block_w2_inv = generate_mux_logic(vals_w2_inv, "val_w2_inv", width)
    block_w3_inv = generate_mux_logic(vals_w3_inv, "val_w3_inv", width)

    verilog_code = f"""module twiddle_interface #(
    parameter NB_DATA  = {NB_DATA},
    parameter NBF_DATA = {NBF_DATA}
)(
    input                      i_clk,
    input                      i_rst,
    input                      i_valid,
    input                      i_inverse,
    input  signed [NB_DATA-1:0] i_data0_re, i_data0_im,
    input  signed [NB_DATA-1:0] i_data1_re, i_data1_im,
    input  signed [NB_DATA-1:0] i_data2_re, i_data2_im,
    input  signed [NB_DATA-1:0] i_data3_re, i_data3_im,
    output reg signed [NB_DATA-1:0] o_data0_re, o_data0_im,
    output reg signed [NB_DATA-1:0] o_data1_re, o_data1_im,
    output reg signed [NB_DATA-1:0] o_data2_re, o_data2_im,
    output reg signed [NB_DATA-1:0] o_data3_re, o_data3_im,
    output reg                      o_valid
);

reg [2:0] cnt_q;
reg       inv_q;
reg       val_q, val_2q;

reg signed [NB_DATA-1:0] data0_re_q, data0_im_q;
reg signed [NB_DATA-1:0] data1_re_q, data1_im_q;
reg signed [NB_DATA-1:0] data2_re_q, data2_im_q;
reg signed [NB_DATA-1:0] data3_re_q, data3_im_q;
reg signed [NB_DATA-1:0] data0_re_2q, data0_im_2q;

wire signed [NB_DATA-1:0] mult1_re, mult1_im;
wire signed [NB_DATA-1:0] mult2_re, mult2_im;
wire signed [NB_DATA-1:0] mult3_re, mult3_im;

wire [2*NB_DATA-1:0] val_w1_fwd, val_w2_fwd, val_w3_fwd;
wire [2*NB_DATA-1:0] val_w1_inv, val_w2_inv, val_w3_inv;

{block_w1_fwd}
{block_w2_fwd}
{block_w3_fwd}

{block_w1_inv}
{block_w2_inv}
{block_w3_inv}

wire [2*NB_DATA-1:0] w1_selected, w2_selected, w3_selected;

assign w1_selected = inv_q ? val_w1_inv : val_w1_fwd;
assign w2_selected = inv_q ? val_w2_inv : val_w2_fwd;
assign w3_selected = inv_q ? val_w3_inv : val_w3_fwd;


always @(posedge i_clk) begin
    if (i_rst) begin
        cnt_q  <= 3'd0;
        val_q  <= 1'b0;
        val_2q <= 1'b0;
        inv_q  <= 1'b0;
    end 
    else begin
        val_q  <= i_valid;
        val_2q <= val_q;
        if (i_valid) inv_q <= i_inverse;
        if (i_valid) begin
            if (cnt_q == 3'd7) cnt_q <= 3'd0;
            else               cnt_q <= cnt_q + 1'd1;
        end
    end
end

always @(posedge i_clk) begin
    if (i_valid) begin
        data0_re_q <= i_data0_re; data0_im_q <= i_data0_im;
        data1_re_q <= i_data1_re; data1_im_q <= i_data1_im;
        data2_re_q <= i_data2_re; data2_im_q <= i_data2_im;
        data3_re_q <= i_data3_re; data3_im_q <= i_data3_im;
    end
end

always @(posedge i_clk) begin
    data0_re_2q <= data0_re_q;
    data0_im_2q <= data0_im_q;
end

complex_multiplier #(
    .NB_INPUT(NB_DATA), .NBF_INPUT(NBF_DATA),
    .NB_OUTPUT(NB_DATA), .NBF_OUTPUT(NBF_DATA)
) u_mult_1 (
    .i_clk    (i_clk), 
    .i_real_A (data1_re_q), 
    .i_imag_A (data1_im_q),
    .i_real_B (w1_selected[2*NB_DATA-1 : NB_DATA]), 
    .i_imag_B (w1_selected[NB_DATA-1 : 0]),
    .o_real   (mult1_re), 
    .o_imag   (mult1_im)
);
complex_multiplier #(
    .NB_INPUT(NB_DATA), .NBF_INPUT(NBF_DATA),
    .NB_OUTPUT(NB_DATA), .NBF_OUTPUT(NBF_DATA)
) u_mult_2 (
    .i_clk    (i_clk), 
    .i_real_A (data2_re_q), 
    .i_imag_A (data2_im_q),
    .i_real_B (w2_selected[2*NB_DATA-1 : NB_DATA]), 
    .i_imag_B (w2_selected[NB_DATA-1 : 0]),
    .o_real   (mult2_re), 
    .o_imag   (mult2_im)
);
complex_multiplier #(
    .NB_INPUT(NB_DATA), .NBF_INPUT(NBF_DATA),
    .NB_OUTPUT(NB_DATA), .NBF_OUTPUT(NBF_DATA)
) u_mult_3 (
    .i_clk    (i_clk), 
    .i_real_A (data3_re_q), 
    .i_imag_A (data3_im_q),
    .i_real_B (w3_selected[2*NB_DATA-1 : NB_DATA]), 
    .i_imag_B (w3_selected[NB_DATA-1 : 0]),
    .o_real   (mult3_re), 
    .o_imag   (mult3_im)
);

always @(posedge i_clk) begin
    if (i_rst) begin
        o_data0_re <= 0; o_data0_im <= 0;
        o_data1_re <= 0; o_data1_im <= 0;
        o_data2_re <= 0; o_data2_im <= 0;
        o_data3_re <= 0; o_data3_im <= 0;
        o_valid    <= 0;
    end 
    else begin
        o_valid <= val_2q; 
        if (val_2q) begin
            o_data0_re <= data0_re_2q;
            o_data0_im <= data0_im_2q;
            o_data1_re <= mult1_re;
            o_data1_im <= mult1_im;
            o_data2_re <= mult2_re;
            o_data2_im <= mult2_im;
            o_data3_re <= mult3_re;
            o_data3_im <= mult3_im;
        end
    end
end

endmodule
"""
    with open(filename, "w") as f:
        f.write(verilog_code)

    print(f"RTL generated successfully: {filename}")

if __name__ == "__main__":
    generate_rtl()