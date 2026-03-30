#include <algorithm>
#include <cstdint>
#include <cstdlib>
#include <deque>
#include <fstream>
#include <iostream>
#include <sstream>
#include <string>
#include <vector>

namespace {

constexpr int kTaps = 32;

// Default template from ip_repo/daphne3_ip/rtl/selftrig/eia_selftrig/st_xc.vhd
const int kTemplate[kTaps] = {
    1, 0, 0, 0, 0, 0, -1, -1,
    -1, -1, -1, -2, -2, -3, -4, -4,
    -5, -5, -6, -7, -6, -7, -7, -7,
    -7, -6, -5, -4, -3, -2, -1, 0
};

struct Options {
    std::string input_path;
    std::string output_path = "xcorr_out.csv";
    std::string template_path;
    int64_t threshold = 0;
    bool unsigned14 = false;
};

void PrintUsage(const char* prog) {
    std::cerr
        << "Usage: " << prog << " --input <waveform.txt> [options]\n"
        << "Options:\n"
        << "  --output <file.csv>     Output CSV path (default: xcorr_out.csv)\n"
        << "  --template <file.txt>   Template coefficients, one per line\n"
        << "  --threshold <int>       Trigger threshold (signed)\n"
        << "  --unsigned14            Treat input as unsigned 14-bit (0..16383)\n";
}

bool ParseArgs(int argc, char** argv, Options& opt) {
    for (int i = 1; i < argc; ++i) {
        std::string arg = argv[i];
        if (arg == "--input" && i + 1 < argc) {
            opt.input_path = argv[++i];
        } else if (arg == "--output" && i + 1 < argc) {
            opt.output_path = argv[++i];
        } else if (arg == "--template" && i + 1 < argc) {
            opt.template_path = argv[++i];
        } else if (arg == "--threshold" && i + 1 < argc) {
            opt.threshold = std::strtoll(argv[++i], nullptr, 0);
        } else if (arg == "--unsigned14") {
            opt.unsigned14 = true;
        } else {
            return false;
        }
    }
    return !opt.input_path.empty();
}

int ClampSigned14(int64_t v) {
    if (v > 8191) return 8191;
    if (v < -8192) return -8192;
    return static_cast<int>(v);
}

int ClampUnsigned14(int64_t v) {
    if (v > 16383) return 16383;
    if (v < 0) return 0;
    return static_cast<int>(v);
}

bool LoadTemplate(const std::string& path, std::vector<int>& tmpl) {
    std::ifstream in(path);
    if (!in) {
        return false;
    }
    tmpl.clear();
    std::string line;
    while (std::getline(in, line)) {
        if (line.empty()) continue;
        if (line[0] == '#') continue;
        std::istringstream iss(line);
        int v = 0;
        if (!(iss >> v)) continue;
        tmpl.push_back(v);
    }
    return !tmpl.empty();
}

} // namespace

int main(int argc, char** argv) {
    Options opt;
    if (!ParseArgs(argc, argv, opt)) {
        PrintUsage(argv[0]);
        return 1;
    }

    std::vector<int> tmpl;
    if (!opt.template_path.empty()) {
        if (!LoadTemplate(opt.template_path, tmpl)) {
            std::cerr << "Failed to read template file: " << opt.template_path << "\n";
            return 1;
        }
        if (tmpl.size() != kTaps) {
            std::cerr << "Template must have exactly " << kTaps << " coefficients. Got " << tmpl.size() << "\n";
            return 1;
        }
    } else {
        tmpl.assign(kTemplate, kTemplate + kTaps);
    }

    std::ifstream in(opt.input_path);
    if (!in) {
        std::cerr << "Failed to open input file: " << opt.input_path << "\n";
        return 1;
    }

    std::ofstream out(opt.output_path);
    if (!out) {
        std::cerr << "Failed to open output file: " << opt.output_path << "\n";
        return 1;
    }

    out << "index,raw,xcorr,trigger\n";

    std::deque<int> delay_line(kTaps, 0);
    int64_t xcorr_prev = 0;
    int64_t xcorr_prev2 = 0;

    std::string line;
    int64_t index = 0;
    while (std::getline(in, line)) {
        if (line.empty()) continue;
        if (line[0] == '#') continue;
        std::istringstream iss(line);
        int64_t raw_val = 0;
        if (!(iss >> raw_val)) continue;

        int sample = 0;
        if (opt.unsigned14) {
            sample = ClampUnsigned14(raw_val);
            // Interpret unsigned ADC as signed by centering around 0.
            sample = sample - 8192;
        } else {
            sample = ClampSigned14(raw_val);
        }

        delay_line.pop_back();
        delay_line.push_front(sample);

        int64_t xcorr = 0;
        for (int k = 0; k < kTaps; ++k) {
            xcorr += static_cast<int64_t>(tmpl[k]) * static_cast<int64_t>(delay_line[k]);
        }

        int trigger = 0;
        if (xcorr > opt.threshold && xcorr_prev > opt.threshold && xcorr_prev2 <= opt.threshold) {
            trigger = 1;
        }

        out << index << "," << sample << "," << xcorr << "," << trigger << "\n";

        xcorr_prev2 = xcorr_prev;
        xcorr_prev = xcorr;
        ++index;
    }

    return 0;
}
