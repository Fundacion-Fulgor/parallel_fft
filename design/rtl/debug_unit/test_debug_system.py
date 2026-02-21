import cocotb
import random
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

# Configuration
SYS_CLK_PERIOD_NS  = 10  # 100 MHz
SPI_HALF_PERIOD_NS = 25 # 20 MHz (50ns period / 2)

# --- SPI Master Transaction ---
async def spi_master_tx(dut, rw_bit, addr, data_write=0):
    """
    SPI Mode 0 Master @ 20 MHz.
    Frame: [RW, 7b Addr, 8b Data]
    Returns: Read byte (8 bits)
    """
    frame = 0
    if rw_bit: frame |= (1 << 15)
    frame |= ((addr & 0x7F) << 8)
    frame |= (data_write & 0xFF)

    # Start Transaction
    dut.ss_n.value = 0
    await Timer(SPI_HALF_PERIOD_NS * 2, unit='ns') 

    read_byte = 0

    # 16 clocks (MSB first)
    for i in range(15, -1, -1):
        # 1. MOSI Setup (Falling Edge)
        dut.mosi.value = (frame >> i) & 1
        await Timer(SPI_HALF_PERIOD_NS, unit='ns') 
        
        # 2. MISO Sample (Rising Edge)
        dut.sclk.value = 1
        await Timer(1, unit='ns') 
        
        if dut.miso.value.is_resolvable and dut.miso.value:
             read_byte |= (1 << i)
             
        await Timer(SPI_HALF_PERIOD_NS - 1, unit='ns')
        dut.sclk.value = 0

    await Timer(SPI_HALF_PERIOD_NS * 2, unit='ns')
    dut.ss_n.value = 1
    await Timer(SPI_HALF_PERIOD_NS * 2, unit='ns')
    
    return read_byte & 0xFF

# --- Main Test ---
@cocotb.test()
async def test_full_functionality_dual_clock(dut):
    """
    Verifies Probes, Controls, and CDC Snapshot stability.
    System Clk: 50 MHz | SPI Clk: 20 MHz
    """
    
    # 1. Setup Clocks
    cocotb.start_soon(Clock(dut.clk, SYS_CLK_PERIOD_NS, unit="ns").start())
    
    # 2. Init
    dut.rst_n.value = 0
    dut.ss_n.value  = 1
    dut.sclk.value  = 0
    dut.mosi.value  = 0
    
    # Init inputs
    dut.monitor_status.value = 0
    dut.fifo_level.value     = 0
    dut.tap_0.value          = 0
    dut.tap_1.value          = 0

    await Timer(100, unit='ns')
    dut.rst_n.value = 1
    await Timer(100, unit='ns')

    dut._log.info(f"--- STARTING TEST (SYS=50MHz, SPI=20MHz) ---")

    # -------------------------------------------------------
    # 3. Verify PROBES (Standard Read)
    # -------------------------------------------------------
    probes = [
        ("monitor_status", dut.monitor_status, 0x00),
        ("fifo_level",     dut.fifo_level,     0x01),
        ("tap_0",          dut.tap_0,          0x02),
        ("tap_1",          dut.tap_1,          0x03)
    ]

    for name, signal, addr in probes:
        test_val = random.randint(0, 255)
        signal.value = test_val
        await Timer(50, unit='ns') # Wait for CDC sync
        
        dut._log.info(f"Read Probe '{name}' @ 0x{addr:02X} (Expect 0x{test_val:02X})")
        read_val = await spi_master_tx(dut, rw_bit=1, addr=addr)
        
        assert read_val == test_val, f"Probe {name} mismatch! Got 0x{read_val:02X}"

    # -------------------------------------------------------
    # 4. Verify CONTROLS (Write & Readback)
    # -------------------------------------------------------
    controls = [
        ("sw_reset", dut.sw_reset, 0x10),
        ("mode",     dut.mode,     0x11)
    ]

    for name, signal, addr in controls:
        test_val = random.randint(0, 255)
        
        # Write
        dut._log.info(f"Write Control '{name}' @ 0x{addr:02X} (Val 0x{test_val:02X})")
        await spi_master_tx(dut, rw_bit=0, addr=addr, data_write=test_val)
        await RisingEdge(dut.clk)
        
        # Check HW
        assert signal.value == test_val, f"HW Output {name} mismatch!"

        # Readback
        read_val = await spi_master_tx(dut, rw_bit=1, addr=addr)
        assert read_val == test_val, f"Readback {name} mismatch!"

    # -------------------------------------------------------
    # 5. Verify CDC SNAPSHOT "FREEZE"
    # Data changes *during* SPI transaction. Output must be stable.
    # -------------------------------------------------------
    dut._log.info("--- TESTING CDC SNAPSHOT FREEZE ---")
    
    # A. Set initial value
    initial_val = 0xAA
    dut.monitor_status.value = initial_val
    await Timer(50, unit='ns')

    # B. Start SPI Transaction MANUALLY
    dut.ss_n.value = 0 
    # At this falling edge, cdc_snapshot should lock 0xAA
    
    await Timer(SPI_HALF_PERIOD_NS * 2, unit='ns')

    # C. Change input data *while* SS_N is low (SPI Active)
    dut.monitor_status.value = 0xFF 
    dut._log.info("Input changed to 0xFF while SS_N is LOW (Snapshot test)")

    # D. Perform SPI transfer manually
    rw_bit = 1
    addr = 0x00 # monitor_status
    frame = (1 << 15) | ((addr & 0x7F) << 8) | 0x00
    read_byte = 0

    for i in range(15, -1, -1):
        dut.mosi.value = (frame >> i) & 1
        await Timer(SPI_HALF_PERIOD_NS, unit='ns') 
        dut.sclk.value = 1
        await Timer(1, unit='ns')
        if dut.miso.value: read_byte |= (1 << i)
        await Timer(SPI_HALF_PERIOD_NS - 1, unit='ns')
        dut.sclk.value = 0

    await Timer(SPI_HALF_PERIOD_NS, unit='ns')
    dut.ss_n.value = 1
    
    # E. Check Result
    read_payload = read_byte & 0xFF

    dut._log.info(f"Snapshot Result Raw: 0x{read_byte:04X} -> Masked: 0x{read_payload:02X}")
    
    assert read_payload == initial_val, \
        f"CDC Freeze Failed! Read 0x{read_payload:02X} (New), Expected 0x{initial_val:02X} (Old)"

    dut._log.info("--- ALL TESTS PASSED ---")