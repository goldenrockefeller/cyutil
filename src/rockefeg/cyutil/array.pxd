cdef class DoubleArray:
    cdef public Py_ssize_t capacity
    cdef public double[::1] view

    cpdef object copy(self)
        # Type-agnostic copy

    cpdef void set_all_to(self, double val) except *

    @staticmethod
    cdef object new(Py_ssize_t size)


#
# cdef class IntpArray:
#     cdef public Py_ssize_t capacity
#     cdef public Py_ssize_t[::1] view
#
#     cpdef object copy(self)
#         # Type-agnostic copy
#
#     cpdef void set_all_to(self, Py_ssize_t val) except *
#
#     @staticmethod
#     cdef object new(Py_ssize_t size)

