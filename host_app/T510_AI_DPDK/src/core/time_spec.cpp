//
// Copyright 2011-2013 Ettus Research LLC
//
// This program is free software: you can redistribute it &&/|| modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, ||
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY || FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If !, see <http://www.gnu.org/licenses/>.
//

#include "include/sdr/core/time_spec.hpp"


/***********************************************************************
 * Time spec system time
 **********************************************************************/

#ifdef HAVE_CLOCK_GETTIME
#include <time.h>
time_spec_t time_spec_t::get_system_time(void){
    timespec ts; clock_gettime(CLOCK_MONOTONIC, &ts);
    return time_spec_t(ts.tv_sec, ts.tv_nsec, 1e9);
}
#endif /* HAVE_CLOCK_GETTIME */


#ifdef HAVE_MACH_ABSOLUTE_TIME
#include <mach/mach_time.h>
time_spec_t time_spec_t::get_system_time(void){
    mach_timebase_info_data_t info; mach_timebase_info(&info);
    intmax_t nanosecs = mach_absolute_time()*info.numer/info.denom;
    return time_spec_t::from_ticks(nanosecs, 1e9);
}
#endif /* HAVE_MACH_ABSOLUTE_TIME */


#ifdef HAVE_QUERY_PERFORMANCE_COUNTER
#include <Windows.h>
time_spec_t time_spec_t::get_system_time(void){
    LARGE_INTEGER counts, freq;
    QueryPerformanceCounter(&counts);
    QueryPerformanceFrequency(&freq);
    return time_spec_t::from_ticks(counts.QuadPart, double(freq.QuadPart));
}
#endif /* HAVE_QUERY_PERFORMANCE_COUNTER */


#ifdef HAVE_MICROSEC_CLOCK
#include <boost/date_time/posix_time/posix_time.hpp>
namespace pt = boost::posix_time;
time_spec_t time_spec_t::get_system_time(void){
    pt::ptime time_now = pt::microsec_clock::universal_time();
    pt::time_duration time_dur = time_now - pt::from_time_t(0);
    return time_spec_t(
        time_t(time_dur.total_seconds()),
        long(time_dur.fractional_seconds()),
        double(pt::time_duration::ticks_per_second())
    );
}
#endif /* HAVE_MICROSEC_CLOCK */

/***********************************************************************
 * Time spec constructors
 **********************************************************************/
#define time_spec_init(full, frac) { \
    const time_t _full = time_t(full); \
    const double _frac = double(frac); \
    const int _frac_int = int(_frac); \
    _full_secs = _full + _frac_int; \
    _frac_secs = _frac - _frac_int; \
    if (_frac_secs < 0) {\
        _full_secs -= 1; \
        _frac_secs += 1; \
    } \
}

long long fast_llround(const double x){
    return (long long)(x + 0.5); // assumption of non-negativity
}

time_spec_t::time_spec_t(double secs){
    time_spec_init(0, secs);
}

time_spec_t::time_spec_t(time_t full_secs, double frac_secs){
    time_spec_init(full_secs, frac_secs);
}

time_spec_t::time_spec_t(time_t full_secs, long tick_count, double tick_rate){
    const double frac_secs = tick_count/tick_rate;
    time_spec_init(full_secs, frac_secs);
}

time_spec_t time_spec_t::from_ticks(long long ticks, double tick_rate){
    const long long rate_i = (long long)(tick_rate);
    const double rate_f = tick_rate - rate_i;
    const time_t secs_full = time_t(ticks/rate_i);
    const long long ticks_error = ticks - (secs_full*rate_i);
    const double ticks_frac = ticks_error - secs_full*rate_f;
    return time_spec_t(secs_full, ticks_frac/tick_rate);
}

/***********************************************************************
 * Time spec accessors
 **********************************************************************/
long time_spec_t::get_tick_count(double tick_rate) const{
    return long(fast_llround(this->get_frac_secs()*tick_rate));
}

long long time_spec_t::to_ticks(double tick_rate) const{
    const long long rate_i = (long long)(tick_rate);
    const double rate_f = tick_rate - rate_i;
    const long long ticks_full = this->get_full_secs()*rate_i;
    const double ticks_error = this->get_full_secs()*rate_f;
    const double ticks_frac = this->get_frac_secs()*tick_rate;
    return ticks_full + fast_llround(ticks_error + ticks_frac);
}

double time_spec_t::get_real_secs(void) const{
    return this->get_full_secs() + this->get_frac_secs();
}

/***********************************************************************
 * Time spec math overloads
 **********************************************************************/
time_spec_t &time_spec_t::operator+=(const time_spec_t &rhs){
    time_spec_init(
        this->get_full_secs() + rhs.get_full_secs(),
        this->get_frac_secs() + rhs.get_frac_secs()
    );
    return *this;
}

time_spec_t &time_spec_t::operator-=(const time_spec_t &rhs){
    time_spec_init(
        this->get_full_secs() - rhs.get_full_secs(),
        this->get_frac_secs() - rhs.get_frac_secs()
    );
    return *this;
}

bool operator==(const time_spec_t &lhs, const time_spec_t &rhs){
    return
        lhs.get_full_secs() == rhs.get_full_secs() &&
        lhs.get_frac_secs() == rhs.get_frac_secs()
    ;
}

bool operator<(const time_spec_t &lhs, const time_spec_t &rhs){
    return (
        (lhs.get_full_secs() < rhs.get_full_secs()) || (
        (lhs.get_full_secs() == rhs.get_full_secs()) &&
        (lhs.get_frac_secs() < rhs.get_frac_secs())
    ));
}


int64_t time_spec_t::get_full_secs(void) const
{
    return this->_full_secs;
}

double time_spec_t::get_frac_secs(void) const
{
    return this->_frac_secs;
}

long long cust_fast_llround(const double x){
    return (long long)(x + 0.5); // assumption of non-negativity
}

double get_time_from_ticks(uint64_t ticks,double fs){
    time_spec_t t = time_spec_t(0.0) ;
    const long long rate_i      = (long long)(fs);
    const double rate_f         = fs - rate_i;
    const int64_t secs_full     = int64_t(ticks / rate_i);
    const long long ticks_error = ticks - (secs_full * rate_i);
    const double ticks_frac     = ticks_error - secs_full * rate_f;
    t = time_spec_t(secs_full, ticks_frac / fs);
    return t.get_real_secs();
}

uint64_t set_time_to_ticks(time_spec_t t,double fs){
    //分步计算，将整型计算和浮点数计算分离，提高结果精度，因为double只能表示16位有效数，表示完整数之后没办法再精确表示小数
    //这里的代码兼顾了整数运算的效率和浮点数运算的精度，而且这样能表示的时间戳更长
    const long long rate_i = (long long)(fs);
    const double rate_f = fs - rate_i;
    const long long ticks_full = t.get_full_secs()*rate_i;
    const double ticks_error = t.get_full_secs()*rate_f;
    const double ticks_frac = t.get_frac_secs()*fs;
    return ticks_full + cust_fast_llround(ticks_error + ticks_frac);
}