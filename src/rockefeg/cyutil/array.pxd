cdef DoubleArray new_DoubleArray(Py_ssize_t size)

cdef class DoubleArray:
    cdef public Py_ssize_t capacity
    cdef public double[::1] view

    cpdef object copy(self, object new_arr = ?)
        # Type-agnostic copy

    cpdef void set_all_to(self, double val) except *


