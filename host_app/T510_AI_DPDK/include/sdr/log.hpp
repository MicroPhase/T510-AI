#ifndef CCLOG_LOG_H
#define CCLOG_LOG_H

#include <iostream>
#include <fstream>
#include <string>
#include <chrono>
#include <iomanip>
#include <sstream>
#include <mutex>
#include <cstdarg> // for va_list, va_start, va_end

class Logger {
public:
    //按照日志的重要等级排序
    enum LogLevel {
        DEBUG,
        INFO,
        WARNING,
        PERROR
    };
    //CONSOLE表示日志在终端打印，FILE表示日志会被记录到文件中
    enum OutputType {
        TO_CONSOLE,
        TO_FILE,
        TO_BOTH
    };
    //这里的static表示这是个静态成员变量，属于类而不是类的特定某个成员对象
    static Logger& getInstance() {
        //只能访问类的非静态成员变量
        static Logger instance;
        return instance;
    }

    void setOutput(OutputType type) {
        outputType = type;
    }

    void setLogLevel(LogLevel level) {
        logLevel = level;
    }

    void setLogFile(const std::string& filename) {
        logFileName = filename;
    }

    void setShowDebugInfo(bool show) {
        showDebugInfo = show;
    }

    void log(LogLevel level, const std::string& file, int line, const std::string& function, const char* format, ...) {
        //这里的logLevel应该是显示的最低的日志等级
        if (level < logLevel) return;

        va_list args;
        va_start(args, format);
        std::string message = formatMessage(format, args);
        va_end(args);

        std::string output = currentDateTime() + " [" + levelToString(level) + "] " + message;

        if (showDebugInfo) {
            output += " (" + file + ":" + std::to_string(line) + " " + function + ")";
        }

        std::lock_guard<std::mutex> guard(mtx);

        if (outputType == TO_CONSOLE || outputType == TO_BOTH) {
            std::cout << colorCode(level) << output << "\033[0m" << std::endl;
        }

        if (outputType == TO_FILE || outputType == TO_BOTH) {
            std::ofstream logFile(logFileName, std::ios_base::app);
            if (logFile.is_open()) {
                logFile << output << std::endl;
            }
        }
    }

private:
    Logger() : logLevel(INFO), outputType(TO_CONSOLE), logFileName("log.txt"), showDebugInfo(false) {}
    ~Logger() = default;
    Logger(const Logger&) = delete;
    Logger& operator=(const Logger&) = delete;

    LogLevel logLevel;
    OutputType outputType;
    std::string logFileName;
    bool showDebugInfo;
    std::mutex mtx;

    std::string currentDateTime() {
        auto now = std::chrono::system_clock::now();
        auto ms = std::chrono::duration_cast<std::chrono::milliseconds>(now.time_since_epoch()) % 1000;
        auto in_time_t = std::chrono::system_clock::to_time_t(now);

        std::ostringstream ss;
        ss << std::put_time(std::localtime(&in_time_t), "%Y-%m-%d %H:%M:%S")
           << '.' << std::setfill('0') << std::setw(3) << ms.count();
        return ss.str();
    }

    std::string levelToString(LogLevel level) {
        switch (level) {
            case DEBUG: return "DEBUG";
            case INFO: return "INFO";
            case WARNING: return "WARNING";
            case PERROR: return "ERROR";
            default: return "UNKNOWN";
        }
    }

    std::string colorCode(LogLevel level) {
        switch (level) {
            case DEBUG: return "\033[34m";   // Blue
            case INFO: return "\033[32m";    // Green
            case WARNING: return "\033[33m"; // Yellow
            case PERROR: return "\033[31m";   // Red
            default: return "\033[0m";       // Reset
        }
    }
    //向一个字符串缓冲区打印格式化字符串
    std::string formatMessage(const char* format, va_list args) {
        char buffer[1024]; // Adjust the buffer size if needed
        vsnprintf(buffer, sizeof(buffer), format, args); // Format the string
        return std::string(buffer);
    }
};

// Convenience macros for easier logging with file and line information
#define LOG_DEBUG(format, ...) Logger::getInstance().log(Logger::DEBUG, __FILE__, __LINE__, __FUNCTION__, format, ##__VA_ARGS__)
#define LOG_INFO(format, ...) Logger::getInstance().log(Logger::INFO, __FILE__, __LINE__, __FUNCTION__, format, ##__VA_ARGS__)
#define LOG_WARNING(format, ...) Logger::getInstance().log(Logger::WARNING, __FILE__, __LINE__, __FUNCTION__, format, ##__VA_ARGS__)
#define LOG_ERROR(format, ...) Logger::getInstance().log(Logger::PERROR, __FILE__, __LINE__, __FUNCTION__, format, ##__VA_ARGS__)

#endif //CCLOG_LOG_H
