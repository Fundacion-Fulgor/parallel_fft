module debug_unit #(
  parameter integer NB_ADDR = 7,
  parameter integer NB_DATA = 8
)(
  input  wire                 clk,
  input  wire                 rst_n,
  // SPI Slave Interface
  input  wire [NB_ADDR-1:0]   spi_addr,
  /* verilator lint_off UNUSEDSIGNAL */
  input  wire [NB_DATA-1:0]   spi_wdata,
  /* verilator lint_on UNUSEDSIGNAL */
  input  wire                 spi_wr_en,
  // NOTA: spi_ss_n eliminado porque no hay snapshot
  output reg  [NB_DATA-1:0]   spi_rdata,

  // Probe Inputs
  input  wire [NB_DATA-1:0]   status_flags,
  input  wire [NB_DATA-1:0]   error_flags,
  input  wire [NB_DATA-1:0]   cnt_inputs,
  input  wire [NB_DATA-1:0]   cnt_outputs,
  input  wire [NB_DATA-1:0]   last_out_re,
  input  wire [NB_DATA-1:0]   last_out_im,
  input  wire [NB_DATA-1:0]   mid_data_re,
  
  // Control Outputs
  output reg  [2:0]           sys_config
);

  // Address Map
  localparam [NB_ADDR-1:0] ADDR_STATUS_FLAGS = 'h00;
  localparam [NB_ADDR-1:0] ADDR_ERROR_FLAGS  = 'h01;
  localparam [NB_ADDR-1:0] ADDR_CNT_INPUTS   = 'h02;
  localparam [NB_ADDR-1:0] ADDR_CNT_OUTPUTS  = 'h03;
  localparam [NB_ADDR-1:0] ADDR_LAST_OUT_RE  = 'h04;
  localparam [NB_ADDR-1:0] ADDR_LAST_OUT_IM  = 'h05;
  localparam [NB_ADDR-1:0] ADDR_MID_DATA_RE  = 'h06;
  localparam [NB_ADDR-1:0] ADDR_SYS_CONFIG   = 'h10;

  // Write Logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      sys_config <= 3'b000;
    end
    else begin
      if (spi_wr_en) begin
        /* verilator lint_off UNUSEDSIGNAL */
        case (spi_addr)
          ADDR_SYS_CONFIG: sys_config <= spi_wdata[2:0];
          default:         sys_config <= sys_config;
        endcase
        /* verilator lint_on UNUSEDSIGNAL */
      end
    end
  end

  // Read Logic (Direct Read - Single Clock Domain)
  always @(*) begin
    case (spi_addr)
      // Probes
      ADDR_STATUS_FLAGS: spi_rdata = status_flags;
      ADDR_ERROR_FLAGS:  spi_rdata = error_flags;
      ADDR_CNT_INPUTS:   spi_rdata = cnt_inputs;
      ADDR_CNT_OUTPUTS:  spi_rdata = cnt_outputs;
      ADDR_LAST_OUT_RE:  spi_rdata = last_out_re;
      ADDR_LAST_OUT_IM:  spi_rdata = last_out_im;
      ADDR_MID_DATA_RE:  spi_rdata = mid_data_re;
      
      // Controls (Readback)
      ADDR_SYS_CONFIG:   spi_rdata = {{(NB_DATA-3){1'b0}}, sys_config};
      
      default:           spi_rdata = {NB_DATA{1'b0}};
    endcase
  end

endmodule