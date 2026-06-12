#include <thread>
#include "include/sdr/core/zero_copy.hpp"

using namespace sdr;
using namespace sdr::core;

namespace sdr {namespace core {
    static size_t pad_to_boundary(size_t bytes, size_t alignment)
    {
        return bytes + (alignment - bytes) % alignment;
    }
    
    class buffer_pool_impl : public buffer_pool
    {
    public:
        buffer_pool_impl(const std::vector<ptr_type>& ptrs,
                         std::shared_ptr<char[]> mem)
            : _ptrs(ptrs), _mem(std::move(mem)) {}
    
        ptr_type at(size_t index) const override { return _ptrs.at(index); }
        size_t size() const override { return _ptrs.size(); }
    
    private:
        std::vector<ptr_type> _ptrs;
        std::shared_ptr<char[]> _mem;
    };
    
    buffer_pool::sptr buffer_pool::make(
            size_t num_buffs, size_t buff_size, size_t alignment)
    {
        const size_t padded_buff_size = pad_to_boundary(buff_size, alignment);
    
        std::shared_ptr<char[]> mem(new char[padded_buff_size * num_buffs + alignment - 1],
                                    std::default_delete<char[]>());
    
        const size_t mem_start = pad_to_boundary(size_t(mem.get()), alignment);
    
        std::vector<ptr_type> ptrs(num_buffs);
        for (size_t i = 0; i < num_buffs; i++)
            ptrs[i] = (ptr_type)(mem_start + padded_buff_size * i);
    
        return std::make_shared<buffer_pool_impl>(ptrs, mem);
    }
    
}}