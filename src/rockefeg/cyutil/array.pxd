

cdef class DoubleArray:
    cdef public Py_ssize_t capacity
    cdef public double[::1] view

    cpdef copy(self, copy_obj = ?)
        # Type-agnostic copy

    cpdef void set_all_to(self, double val) except *

cdef DoubleArray new_DoubleArray(Py_ssize_t size)


