

cdef class DoubleArray:
    cdef public Py_ssize_t capacity
    cdef public double[::1] view
    cdef base
    # DO NOT SET THE VIEW OR CAPACITY, unless you know what you are doing.
    # You can access the view and read the capacity.
    # DO NOT Inherit from DoubleArray, unless you know what you are doing.

    cpdef copy(self, copy_obj = ?)
        # Type-agnostic copy

    cpdef void set_all_to(self, double val) except *

cdef DoubleArray new_DoubleArray(Py_ssize_t size)


