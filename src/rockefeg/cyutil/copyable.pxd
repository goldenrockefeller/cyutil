

cdef class Copyable:
    cpdef void copy_from(self, object obj) except *

    cpdef object copy(self)