//
// Created by jcc on 25-4-9.
//

#ifndef SOAPY_CONFIG_HPP
#define SOAPY_CONFIG_HPP

#include "./log.hpp"

#ifdef _WIN32
#define API_EXPORT __declspec(dllexport)
#else
#define API_EXPORT __attribute__((visibility("default")))
#endif


#endif //SOAPY_CONFIG_HPP
