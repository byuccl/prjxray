#include <functional>
#include <algorithm>
#include <fstream>
#include <iostream>
#include <iterator>
#include <string>
#include <vector>

#include <absl/strings/str_cat.h>
#include <absl/strings/str_split.h>
#include <absl/time/clock.h>
#include <absl/time/time.h>
#include <gflags/gflags.h>
#include <prjxray/memory_mapped_file.h>
#include <prjxray/xilinx/xc7series/bitstream_reader.h>
#include <prjxray/xilinx/xc7series/bitstream_writer.h>
#include <prjxray/xilinx/xc7series/command.h>
#include <prjxray/xilinx/xc7series/configuration.h>
#include <prjxray/xilinx/xc7series/configuration_options_0_value.h>
#include <prjxray/xilinx/xc7series/configuration_packet_with_payload.h>
#include <prjxray/xilinx/xc7series/ecc.h>
#include <prjxray/xilinx/xc7series/nop_packet.h>
#include <prjxray/xilinx/xc7series/part.h>

DEFINE_string(part_name, "", "");
DEFINE_string(part_file, "", "Definition file for target 7-series part");
DEFINE_string(bitstream_file,
              "",
              "Initial partial bitstream to which the deltas are applied.");
DEFINE_string(
    frm_file,
    "",
    "File containing a list of frame deltas to be applied to the base "
    "bitstream.  Each line in the file is of the form: "
    "<frame_address> <word1>,...,<word101>.");
DEFINE_string(output_file, "", "Write patched bitsteam to file");

namespace xc7series = prjxray::xilinx::xc7series;

int main(int argc, char* argv[]) {
	gflags::SetUsageMessage(argv[0]);
	gflags::ParseCommandLineFlags(&argc, &argv, true);

	auto part = xc7series::Part::FromFile(FLAGS_part_file);
	if (!part) {
		std::cerr << "Part file not found or invalid" << std::endl;
		return 1;
	}

	auto bitstream_file =
	    prjxray::MemoryMappedFile::InitWithFile(FLAGS_bitstream_file);
	if (!bitstream_file) {
		std::cerr << "Can't open base bitstream file: "
		          << FLAGS_bitstream_file << std::endl;
		return 1;
	}

	auto bitstream_reader = xc7series::BitstreamReader::InitWithBytes(
	    bitstream_file->as_bytes());
	if (!bitstream_reader) {
		std::cout
		    << "Bitstream does not appear to be a 7-series bitstream!"
		    << std::endl;
		return 1;
	}

	auto bitstream_config =
	    xc7series::Configuration::InitWithPackets(*part, *bitstream_reader);
	if (!bitstream_config) {
		std::cerr << "Bitstream does not appear to be for this part"
		          << std::endl;
		return 1;
	}

	// Copy the base frames to mutable collections
    std::map<xc7series::FrameAddress, std::vector<uint32_t>> cfg_clb_frames;
	for (auto& frame_val : bitstream_config->cfg_clb_frames()) {
		auto& cur_frame = cfg_clb_frames[frame_val.first];

		std::copy(frame_val.second.begin(), frame_val.second.end(),
		          std::back_inserter(cur_frame));
	}
    
	std::map<xc7series::FrameAddress, std::vector<uint32_t>> frames;
	for (auto& frame_val : bitstream_config->frames()) {
		auto& cur_frame = frames[frame_val.first];

		std::copy(frame_val.second.begin(), frame_val.second.end(),
		          std::back_inserter(cur_frame));
	}
    
    // Assuming the map has been constructed so the first frame
    // is the smallest value frame address.
    uint32_t roi_start_frame_address = frames.begin()->first;

	// Apply the deltas.
	std::ifstream frm_file(FLAGS_frm_file);
	if (!frm_file) {
		std::cerr << "Unable to open frm file: " << FLAGS_frm_file
		          << std::endl;
		return 1;
	}

	std::string frm_line;
	while (std::getline(frm_file, frm_line)) {
        // Skip commented lines (lines starting with #)
		if (frm_line[0] == '#')
			continue;

		std::pair<std::string, std::string> frame_delta =
		    absl::StrSplit(frm_line, ' ');

		uint32_t frame_address =
		    std::stoul(frame_delta.first, nullptr, 16);
            
        // Skip lines whose frame addresses weren't in the base bitstream.
        // TODO: Make .frm files only contain frame addresses for the 
        // desired reconfigurable area?
        if (frames.find(frame_address) == frames.end()) {
            continue;
        }

		auto& frame_data = frames[frame_address];
		frame_data.resize(101);

		std::vector<std::string> frame_data_strings =
		    absl::StrSplit(frame_delta.second, ',');
		if (frame_data_strings.size() != 101) {
			std::cerr << "Frame " << std::hex << frame_address
			          << ": found " << std::dec
			          << frame_data_strings.size()
			          << "words instead of 101";
			continue;
		};
        
        std::vector<uint32_t> frame_data_ints;
        frame_data_ints.resize(101);
        
        // Replace the data in the ROI with the bits from the .frm file
		std::transform(frame_data_strings.begin(),
		               frame_data_strings.end(), frame_data.begin(),
		               [](const std::string& val) -> uint32_t {
			               return std::stoul(val, nullptr, 16);
                        });

		uint32_t ecc = 0;
		for (size_t ii = 0; ii < frame_data.size(); ++ii) {
			ecc = xc7series::icap_ecc(ii, frame_data[ii], ecc);
		}

		// Replace the old ECC with the new.
		frame_data[0x32] &= 0xFFFFE000;
		frame_data[0x32] |= (ecc & 0x1FFF);
	}

	std::vector<std::unique_ptr<xc7series::ConfigurationPacket>>
	    out_packets;
        
    // Generate a type 2 packet to write the CFG_CLB frames
    std::vector<uint32_t> cfg_clb_packet_data;
	for (auto& frame : cfg_clb_frames) {
		std::copy(frame.second.begin(), frame.second.end(),
		          std::back_inserter(cfg_clb_packet_data));

		auto next_address = part->GetNextFrameAddress(frame.first);
		if (next_address &&
		    (next_address->block_type() != frame.first.block_type() ||
		     next_address->is_bottom_half_rows() !=
		         frame.first.is_bottom_half_rows() ||
		     next_address->row() != frame.first.row())) {
			cfg_clb_packet_data.insert(cfg_clb_packet_data.end(), 202, 0);
		}
	}
	cfg_clb_packet_data.insert(cfg_clb_packet_data.end(), 202, 0);
    
    // Initialization sequence
    
    // 20 00 00 00
	out_packets.emplace_back(new xc7series::NopPacket());
    
    // 0x30008001 Packet Type 1: Write CMD
    // 0x00000007 Reset CRC
	out_packets.emplace_back(
	    new xc7series::ConfigurationPacketWithPayload<1>(
	        xc7series::ConfigurationPacket::Opcode::Write,
	        xc7series::ConfigurationRegister::CMD,
	        {static_cast<uint32_t>(xc7series::Command::RCRC)}));
            
    // 20 00 00 00
	out_packets.emplace_back(new xc7series::NopPacket());
    
    // 20 00 00 00
	out_packets.emplace_back(new xc7series::NopPacket());
    
    // 30 01 80 01 Packet Type 1: Write IDCODE register, WORD_COUNT=1
    // 32 bit IDCODE
	out_packets.emplace_back(
	    new xc7series::ConfigurationPacketWithPayload<1>(
	        xc7series::ConfigurationPacket::Opcode::Write,
	        xc7series::ConfigurationRegister::IDCODE, {part->idcode()}));

    // 30 00 80 01
    // 00 00 00 01 CMD[4:0]=00001 (binary) = WCFG (Write configuration data)
	out_packets.emplace_back(
	    new xc7series::ConfigurationPacketWithPayload<1>(
	        xc7series::ConfigurationPacket::Opcode::Write,
	        xc7series::ConfigurationRegister::CMD,
	        {static_cast<uint32_t>(xc7series::Command::WCFG)}));

    // 20 00 00 00
	out_packets.emplace_back(new xc7series::NopPacket());
    
    // 30 00 20 01 Set FAR 
    // FAR = 01 00 00 00
    // TODO: Does this CFG_CLB addr ever change for different devices? Probably not...
	out_packets.emplace_back(
	    new xc7series::ConfigurationPacketWithPayload<1>(
	        xc7series::ConfigurationPacket::Opcode::Write,
	        xc7series::ConfigurationRegister::FAR, {0x1000000}));
            
    // 20 00 00 00
	out_packets.emplace_back(new xc7series::NopPacket());
    
	// Frame data write
    // 30 00 40 00 Packet Type 1: Write FDRI register, WORD_COUNT=0
	out_packets.emplace_back(new xc7series::ConfigurationPacket(
	    1, xc7series::ConfigurationPacket::Opcode::Write,
	    xc7series::ConfigurationRegister::FDRI, {}));
        
    // Packet Type 2: Write FDRI register, WORD_COUNT=packet_data    
	out_packets.emplace_back(new xc7series::ConfigurationPacket(
	    2, xc7series::ConfigurationPacket::Opcode::Write,
	    xc7series::ConfigurationRegister::FDRI, cfg_clb_packet_data));        
        
    // Finalization sequence
    
    // 0x30008001 Packet Type 1: Write CMD
    // 0x00000007 Reset CRC
	out_packets.emplace_back(
	    new xc7series::ConfigurationPacketWithPayload<1>(
	        xc7series::ConfigurationPacket::Opcode::Write,
	        xc7series::ConfigurationRegister::CMD,
	        {static_cast<uint32_t>(xc7series::Command::RCRC)}));

    // 0x30008001 Packet Type 1: Write CMD
    // 0x0000000B Shutdown command?
 	out_packets.emplace_back(
	    new xc7series::ConfigurationPacketWithPayload<1>(
	        xc7series::ConfigurationPacket::Opcode::Write,
	        xc7series::ConfigurationRegister::CMD, {0xB}));       
    
	// Generate a single type 2 packet that writes everything else at once.
	std::vector<uint32_t> packet_data;
	for (auto& frame : frames) {
		std::copy(frame.second.begin(), frame.second.end(),
		          std::back_inserter(packet_data));

		auto next_address = part->GetNextFrameAddress(frame.first);
		if (next_address &&
		    (next_address->block_type() != frame.first.block_type() ||
		     next_address->is_bottom_half_rows() !=
		         frame.first.is_bottom_half_rows() ||
		     next_address->row() != frame.first.row())) {
			packet_data.insert(packet_data.end(), 202, 0);
		}
	}
	packet_data.insert(packet_data.end(), 202, 0);
    
    
	// Initialization sequence
    
    // 20 00 00 00
	out_packets.emplace_back(new xc7series::NopPacket());
    
    
    // 0x30008001 Packet Type 1: Write CMD
    // 0x00000007 Reset CRC
	out_packets.emplace_back(
	    new xc7series::ConfigurationPacketWithPayload<1>(
	        xc7series::ConfigurationPacket::Opcode::Write,
	        xc7series::ConfigurationRegister::CMD,
	        {static_cast<uint32_t>(xc7series::Command::RCRC)}));
            
    // 20 00 00 00
	out_packets.emplace_back(new xc7series::NopPacket());
    
    // 20 00 00 00
	out_packets.emplace_back(new xc7series::NopPacket());
    
    // 20 00 00 00
	out_packets.emplace_back(new xc7series::NopPacket());
    
    // 20 00 00 00
	out_packets.emplace_back(new xc7series::NopPacket());
    
    // 0x30008001 Packet Type 1: Write CMD
    // 00000000
	out_packets.emplace_back(
	    new xc7series::ConfigurationPacketWithPayload<1>(
	        xc7series::ConfigurationPacket::Opcode::Write,
	        xc7series::ConfigurationRegister::CMD,
	        {static_cast<uint32_t>(xc7series::Command::NOP)}));
    
    // 0x3000C001 Write MASK
    // Mask bits = 00 00 01 00
	out_packets.emplace_back(
	    new xc7series::ConfigurationPacketWithPayload<1>(
	        xc7series::ConfigurationPacket::Opcode::Write,
	        xc7series::ConfigurationRegister::MASK, {0x100}));
            
            
    // 30 00 A0 01 Write CTL0
    // Ctrl0  = 00 00 01 00 masked by set mask
	out_packets.emplace_back(
	    new xc7series::ConfigurationPacketWithPayload<1>(
	        xc7series::ConfigurationPacket::Opcode::Write,
	        xc7series::ConfigurationRegister::CTL0, {0x100}));
            
    // 0x3000C001 Write MASK
    // Mask bits = 00 00 04 00
	out_packets.emplace_back(
	    new xc7series::ConfigurationPacketWithPayload<1>(
	        xc7series::ConfigurationPacket::Opcode::Write,
	        xc7series::ConfigurationRegister::MASK, {0x400}));
                        
    // 30 00 A0 01 Write CTL0
    // Ctrl0  = 00 00 04 00 masked by set mask
	out_packets.emplace_back(
	    new xc7series::ConfigurationPacketWithPayload<1>(
	        xc7series::ConfigurationPacket::Opcode::Write,
	        xc7series::ConfigurationRegister::CTL0, {0x400}));            
            
    // 30 00 80 01
    // 00 00 00 01 CMD[4:0]=00001 (binary) = WCFG (Write configuration data)
	out_packets.emplace_back(
	    new xc7series::ConfigurationPacketWithPayload<1>(
	        xc7series::ConfigurationPacket::Opcode::Write,
	        xc7series::ConfigurationRegister::CMD,
	        {static_cast<uint32_t>(xc7series::Command::WCFG)}));
            
    // 20 00 00 00
	out_packets.emplace_back(new xc7series::NopPacket());
    
    // 30 00 20 01 Set FAR 
    // 00 00 00 00 FAR = roi_start_frame_address
    // I'm assuming we want to set the FAR to the same address the base bitstream uses
	out_packets.emplace_back(
	    new xc7series::ConfigurationPacketWithPayload<1>(
	        xc7series::ConfigurationPacket::Opcode::Write,
	        xc7series::ConfigurationRegister::FAR, {roi_start_frame_address}));
    
    // 20 00 00 00
	out_packets.emplace_back(new xc7series::NopPacket());
    
	// Frame data write
    // 30 00 40 00 Packet Type 1: Write FDRI register, WORD_COUNT=0
	out_packets.emplace_back(new xc7series::ConfigurationPacket(
	    1, xc7series::ConfigurationPacket::Opcode::Write,
	    xc7series::ConfigurationRegister::FDRI, {}));
        
    // Packet Type 2: Write FDRI register, WORD_COUNT=packet_data    
	out_packets.emplace_back(new xc7series::ConfigurationPacket(
	    2, xc7series::ConfigurationPacket::Opcode::Write,
	    xc7series::ConfigurationRegister::FDRI, packet_data));

	// Finalization sequence
    
    // 30 00 80 01 Packet Type 1: Write CMD register, WORD_COUNT=1
    // 00 00 00 0A CMD[4:0]=01010 (binary) = GRESTORE (Pulse GRESTORE signal)
    out_packets.emplace_back(
    new xc7series::ConfigurationPacketWithPayload<1>(
        xc7series::ConfigurationPacket::Opcode::Write,
        xc7series::ConfigurationRegister::CMD,
        {static_cast<uint32_t>(xc7series::Command::GRESTORE)}));

    // 20 00 00 00
	out_packets.emplace_back(new xc7series::NopPacket());

    // 30 00 C0 01 Packet Type 1: Write MASK register, WORD_COUNT=1
    // 00 00 01 00 Bit mask for write to CTL0/CTL1 register. MASK[31:0]=00000100 (hex)
	out_packets.emplace_back(
	    new xc7series::ConfigurationPacketWithPayload<1>(
	        xc7series::ConfigurationPacket::Opcode::Write,
	        xc7series::ConfigurationRegister::MASK, {0x100}));
    
    // 30 00 A0 01 Write CTL0
    // Ctrl0  = 00 00 00 00 masked by set mask
	out_packets.emplace_back(
	    new xc7series::ConfigurationPacketWithPayload<1>(
	        xc7series::ConfigurationPacket::Opcode::Write,
	        xc7series::ConfigurationRegister::CTL0, {0x0}));
    
    // 30 00 80 01 Packet Type 1: Write CMD register, WORD_COUNT=1
    // 00 00 00 05 CMD[4:0]=00101 (binary) = START (Begin STARTUP sequence)
	out_packets.emplace_back(
	    new xc7series::ConfigurationPacketWithPayload<1>(
	        xc7series::ConfigurationPacket::Opcode::Write,
	        xc7series::ConfigurationRegister::CMD, {0x5}));   

    // 20 00 00 00
	out_packets.emplace_back(new xc7series::NopPacket());
   
    // 30 00 20 01 Packet Type 1: Write FAR register, WORD_COUNT=1
    // 03BE0000 FAR (Frame address) = 03BE0000 (hex)
	out_packets.emplace_back(
	    new xc7series::ConfigurationPacketWithPayload<1>(
	        xc7series::ConfigurationPacket::Opcode::Write,
	        xc7series::ConfigurationRegister::FAR, {0x3BE0000}));

    // 30 00 80 01 Packet Type 1: Write CMD register, WORD_COUNT=1
    // 00 00 00 07 CMD[4:0]=00111 (binary) = RCRC (Reset CRC register)
	out_packets.emplace_back(
	    new xc7series::ConfigurationPacketWithPayload<1>(
	        xc7series::ConfigurationPacket::Opcode::Write,
	        xc7series::ConfigurationRegister::CMD,
	        {static_cast<uint32_t>(xc7series::Command::RCRC)}));
   

    // 30 00 80 01 Packet Type 1: Write CMD register, WORD_COUNT=1
    // 00 00 00 0D CMD[4:0]=01101 (binary) = DESYNCH (Reset DALIGN)
	out_packets.emplace_back(
	    new xc7series::ConfigurationPacketWithPayload<1>(
	        xc7series::ConfigurationPacket::Opcode::Write,
	        xc7series::ConfigurationRegister::CMD,
	        {static_cast<uint32_t>(xc7series::Command::DESYNC)}));
   
	for (int ii = 0; ii < 16; ++ii) {
		out_packets.emplace_back(new xc7series::NopPacket());
	}

	// Write bitstream.
	xc7series::BitstreamWriter out_bitstream_writer(out_packets);
	std::ofstream out_file(FLAGS_output_file);
	if (!out_file) {
		std::cerr << "Unable to open file for writting: "
		          << FLAGS_output_file << std::endl;
		return 1;
	}

	// Xilinx BIT header.
	// Sync header
	std::vector<uint8_t> bit_header{0x0,  0x9,  0x0f, 0xf0, 0x0f,
	                                0xf0, 0x0f, 0xf0, 0x0f, 0xf0,
	                                0x00, 0x00, 0x01, 'a'};
	auto build_source = absl::StrCat(FLAGS_frm_file, ";Generator=partial_bitgen");
	bit_header.push_back(
	    static_cast<uint8_t>((build_source.size() + 1) >> 8));
	bit_header.push_back(static_cast<uint8_t>(build_source.size() + 1));
	bit_header.insert(bit_header.end(), build_source.begin(),
	                  build_source.end());
	bit_header.push_back(0x0);

	// Source file.
	bit_header.push_back('b');
	bit_header.push_back(
	    static_cast<uint8_t>((FLAGS_part_name.size() + 1) >> 8));
	bit_header.push_back(static_cast<uint8_t>(FLAGS_part_name.size() + 1));
	bit_header.insert(bit_header.end(), FLAGS_part_name.begin(),
	                  FLAGS_part_name.end());
	bit_header.push_back(0x0);

	// Build timestamp.
	auto build_time = absl::Now();
	auto build_date_string =
	    absl::FormatTime("%E4Y/%m/%d", build_time, absl::UTCTimeZone());
	auto build_time_string =
	    absl::FormatTime("%H:%M:%S", build_time, absl::UTCTimeZone());

	bit_header.push_back('c');
	bit_header.push_back(
	    static_cast<uint8_t>((build_date_string.size() + 1) >> 8));
	bit_header.push_back(
	    static_cast<uint8_t>(build_date_string.size() + 1));
	bit_header.insert(bit_header.end(), build_date_string.begin(),
	                  build_date_string.end());
	bit_header.push_back(0x0);

	bit_header.push_back('d');
	bit_header.push_back(
	    static_cast<uint8_t>((build_time_string.size() + 1) >> 8));
	bit_header.push_back(
	    static_cast<uint8_t>(build_time_string.size() + 1));
	bit_header.insert(bit_header.end(), build_time_string.begin(),
	                  build_time_string.end());
	bit_header.push_back(0x0);

	bit_header.insert(bit_header.end(), {'e', 0x0, 0x0, 0x0, 0x0});
	out_file.write(reinterpret_cast<const char*>(bit_header.data()),
	               bit_header.size());

	auto end_of_header_pos = out_file.tellp();
	auto header_data_length_pos =
	    end_of_header_pos - static_cast<std::ofstream::off_type>(4);

	for (uint32_t word : out_bitstream_writer) {
		out_file.put((word >> 24) & 0xFF);
		out_file.put((word >> 16) & 0xFF);
		out_file.put((word >> 8) & 0xFF);
		out_file.put((word)&0xFF);
	}

	uint32_t length_of_data = out_file.tellp() - end_of_header_pos;

	out_file.seekp(header_data_length_pos);
	out_file.put((length_of_data >> 24) & 0xFF);
	out_file.put((length_of_data >> 16) & 0xFF);
	out_file.put((length_of_data >> 8) & 0xFF);
	out_file.put((length_of_data)&0xFF);

	return 0;
}
