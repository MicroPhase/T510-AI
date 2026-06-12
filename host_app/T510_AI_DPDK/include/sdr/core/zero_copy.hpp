#ifndef SOAPY_ZERO_COPY_HPP
#define SOAPY_ZERO_COPY_HPP

#include <vector>    // std::vector
#include <memory>    // std::shared_ptr
#include <thread>    // std::this_thread
#include <atomic>    // std::atomic
#include <chrono>    // std::chrono
#include <cstddef>   // size_t
#include <utility>   // std::move
#include "../config.hpp"

namespace sdr { namespace core {

        class API_EXPORT buffer_pool{
        public:
            typedef std::shared_ptr<buffer_pool> sptr;
            typedef void* ptr_type;

            virtual ~buffer_pool(void) = default;

            /*!
             * Make a new buffer pool.
             * \param num_buffs the number of buffers to allocate
             * \param buff_size the size of each buffer in bytes
             * \param alignment the alignment boundary in bytes
             * \return a new buffer pool buff_size X num_buffs
             */
            static sptr make(
                    const size_t num_buffs, const size_t buff_size, const size_t alignment = 16);

            //! Get a pointer to the buffer start at the specified index
            virtual ptr_type at(const size_t index) const = 0;

            //! Get the number of buffers in this pool
            virtual size_t size(void) const = 0;
        };

        class API_EXPORT managed_buffer
        {
        public:
            managed_buffer(void) : _ref_count(0), _buffer(nullptr), _length(0) {}

            virtual ~managed_buffer(void) {}

            /*!
             * Signal to the transport that we are done with the buffer.
             * This should be called to release the buffer to the transport object.
             * After calling, the referenced memory should be considered invalid.
             */
            virtual void release(void) = 0;

            /*!
             * Use commit() to re-write the length (for use with send buffers).
             * \param num_bytes the number of bytes written into the buffer
             */
            void commit(size_t num_bytes)
            {
                _length = num_bytes;
            }

            /*!
             * Get a pointer to the underlying buffer.
             * \return a pointer into memory
             */
            template <class T>
            T cast(void) const
            {
                return static_cast<T>(_buffer);
            }

            /*!
             * Get the size of the underlying buffer.
             * \return the number of bytes
             */
            size_t size(void) const
            {
                return _length;
            }

            //! Create smart pointer to a reusable managed buffer
            template <typename T>
            static std::shared_ptr<T> make(T* p, void* buffer, size_t length)
            {
                p->_buffer = buffer;
                p->_length = length;
                p->add_ref();  // Initial reference
                return std::shared_ptr<T>(p, [](T* ptr) {
                    ptr->release_ref();  // Custom deleter
                });
            }

            // Reference count management
            void add_ref()
            {
                _ref_count.fetch_add(1, std::memory_order_relaxed);
            }

            void release_ref()
            {
                if (_ref_count.fetch_sub(1, std::memory_order_release) == 1)
                {
                    std::atomic_thread_fence(std::memory_order_acquire);  // Ensure proper release before calling release
                    release();
                }
            }

            int ref_count() const
            {
                return _ref_count.load(std::memory_order_acquire);
            }

        protected:
            void* _buffer;
            size_t _length;

        private:
            std::atomic<int> _ref_count;  // Atomic reference count
        };

// A managed receive buffer
        class API_EXPORT managed_recv_buffer : public managed_buffer
        {
        public:
            typedef std::shared_ptr<managed_recv_buffer> sptr;
        };

// A managed send buffer
        class API_EXPORT managed_send_buffer : public managed_buffer
        {
        public:
            typedef std::shared_ptr<managed_send_buffer> sptr;
        };

// Transport parameters
        struct zero_copy_xport_params
        {
            zero_copy_xport_params()
                    : recv_frame_size(0)
                    , send_frame_size(0)
                    , num_recv_frames(0)
                    , num_send_frames(0)
                    , recv_buff_size(0)
                    , send_buff_size(0)
            { /* NOP */
            }
            size_t recv_frame_size;
            size_t send_frame_size;
            size_t num_recv_frames;
            size_t num_send_frames;
            size_t recv_buff_size;
            size_t send_buff_size;
        };

        class API_EXPORT zero_copy_if
        {
        public:
            typedef std::shared_ptr<zero_copy_if> sptr;

            virtual ~zero_copy_if(){};

            virtual managed_recv_buffer::sptr get_recv_buff(double timeout = 1.0) = 0;
            virtual size_t get_num_recv_frames(void) const = 0;
            virtual size_t get_recv_frame_size(void) const = 0;

            virtual managed_send_buffer::sptr get_send_buff(double timeout = 0.1,uint32_t len = 24) = 0;
            virtual size_t get_num_send_frames(void) const = 0;
            virtual size_t get_send_frame_size(void) const = 0;
        };
        
                template <typename T>
        bool spin_wait_with_timeout(std::atomic<T>& cond, T value, double timeout)
        {
            if (cond == value)
                return true;
        
            const auto exit_time = std::chrono::high_resolution_clock::now() +
                                   std::chrono::microseconds((int64_t)(timeout * 1e6));
        
            while (cond != value) {
                if (std::chrono::high_resolution_clock::now() > exit_time)
                    return false;
                std::this_thread::yield();
            }
            return true;
        }

        class simple_claimer
        {
        public:
            simple_claimer() { release(); }
        
            void release() { _locked = false; }
        
            bool claim_with_wait(double timeout)
            {
                if (spin_wait_with_timeout(_locked, false, timeout)) {
                    _locked = true;
                    return true;
                }
                return false;
            }
        
        private:
            std::atomic<bool> _locked;
        };

        // Derived Implementation (forward declare)
        class buffer_pool_impl;
    }} // namespace sdr::core

#endif //SOAPY_ZERO_COPY_HPP