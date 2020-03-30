cimport cython

@cython.warn.undeclared(True)
cdef class Copyable:
    cpdef void copy_from(self, object obj) except *:
        pass

    cpdef object copy(self):
        cdef Copyable copy
        copy = self.__class__.__new__(self.__class__)
        copy.copy_from(self)
        return copy
