`timescale 1ns/1ps

module tb_twiddle_interface;

    parameter NB_DATA = 10;
    parameter N_SAMPLES = 8;

    reg clk;
    reg rst;
    reg i_valid;
    reg [2*NB_DATA-1:0] i_signal_0, i_signal_1, i_signal_2, i_signal_3;

    wire [2*NB_DATA-1:0] o_signal_0, o_signal_1, o_signal_2, o_signal_3;
    wire o_valid;
    wire o_last;

    reg [2*NB_DATA-1:0] input_0 [0:N_SAMPLES-1];
    reg [2*NB_DATA-1:0] input_1 [0:N_SAMPLES-1];
    reg [2*NB_DATA-1:0] input_2 [0:N_SAMPLES-1];
    reg [2*NB_DATA-1:0] input_3 [0:N_SAMPLES-1];

    reg [2*NB_DATA-1:0] golden_0 [0:N_SAMPLES-1];
    reg [2*NB_DATA-1:0] golden_1 [0:N_SAMPLES-1];
    reg [2*NB_DATA-1:0] golden_2 [0:N_SAMPLES-1];
    reg [2*NB_DATA-1:0] golden_3 [0:N_SAMPLES-1];

    twiddle_interface #(.NB_DATA(NB_DATA)) dut (
        .o_signal_0(o_signal_0), .o_signal_1(o_signal_1), 
        .o_signal_2(o_signal_2), .o_signal_3(o_signal_3),
        .o_valid(o_valid), .o_last(o_last),
        .i_signal_0(i_signal_0), .i_signal_1(i_signal_1), 
        .i_signal_2(i_signal_2), .i_signal_3(i_signal_3),
        .i_valid(i_valid), .i_rst(rst), .i_clk(clk)
    );

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    initial begin
        $dumpfile("tb_twiddle_interface.vcd");
        $dumpvars(0, tb_twiddle_interface);
    end

    integer i;
    integer error_count;
    integer check_idx;
    initial begin
        $readmemb("input_signal_0.txt", input_0);
        $readmemb("input_signal_1.txt", input_1);
        $readmemb("input_signal_2.txt", input_2);
        $readmemb("input_signal_3.txt", input_3);
        $readmemb("golden_output_0.txt", golden_0);
        $readmemb("golden_output_1.txt", golden_1);
        $readmemb("golden_output_2.txt", golden_2);
        $readmemb("golden_output_3.txt", golden_3);

        rst = 1;
        i_valid = 0;
        {i_signal_0, i_signal_1, i_signal_2, i_signal_3} = 0;
        error_count = 0;
        check_idx = 0;
        #20;
        rst = 0;
        
        for (i=0; i<N_SAMPLES; i=i+1) begin
            @(posedge clk);
            i_valid <= 1;
            i_signal_0 <= input_0[i];
            i_signal_1 <= input_1[i];
            i_signal_2 <= input_2[i];
            i_signal_3 <= input_3[i];
        end

        @(posedge clk);
        i_valid <= 0;
    end

    always @(posedge clk) begin
        if (o_valid) begin
            if (o_signal_0 !== golden_0[check_idx]) error_count = error_count + 1;
            if (o_signal_1 !== golden_1[check_idx]) error_count = error_count + 1;
            if (o_signal_2 !== golden_2[check_idx]) error_count = error_count + 1;
            if (o_signal_3 !== golden_3[check_idx]) error_count = error_count + 1;
            check_idx = check_idx + 1;
        end
    end

    initial begin
        wait(o_last);
        @(posedge clk);
        #10;

        if (error_count == 0 && check_idx == N_SAMPLES) begin
            $display(">>> TEST PASSED <<<");
        end else begin
            $display(">>> TEST FAILED: %0d errors found. Check idx count: %0d <<<", error_count, check_idx);
        end
        
        #20;
        $finish;
    end

endmodule
