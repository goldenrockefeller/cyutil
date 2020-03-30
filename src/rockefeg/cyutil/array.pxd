from .copyable cimport Copyable

cdef class ObjectArray():
    cdef public Py_ssize_t capacity
    cdef public object[::1] view

    cpdef void set_all_to(self, object obj) except *
    cpdef void set_all_with(self, object fn_new_obj) except *

    cpdef void shrink_to_fit(self) except *

    cpdef void repurpose_like(self, ObjectArray other) except *
    cpdef void repurpose(self, Py_ssize_t new_size) except *

    cpdef void empty(self)  except *

    cpdef void remove_extra_refs(self) except *

    cpdef void trim_at(
        self,
        Py_ssize_t pos,
        Py_ssize_t amt,
        bint reuses_refs = ?
        ) except *

    cpdef void extend_at(
        self,
        Py_ssize_t pos,
        Py_ssize_t amt,
        bint reuses_refs = ?
        ) except *

    cpdef void extend(self, Py_ssize_t amt, bint reuses_refs = ?) except *

    cpdef void append(self, object obj, bint reuses_refs = ?)  except *

    cpdef void insert_at(
        self,
        Py_ssize_t pos,
        object obj,
        bint reuses_refs = ?
        ) except *

    cdef object pop(self, bint reuses_refs = ?)

    cdef object pop_at(self, Py_ssize_t pos, bint reuses_refs = ?)

cdef class SheddingObjectArray(ObjectArray):
    pass

cdef class DoubleArray(Copyable):
    cdef public Py_ssize_t capacity
    cdef public double[::1] view

    cpdef void copy_from(self, object obj) except *

    cpdef void repurpose_like(self, DoubleArray other) except *

    cpdef void repurpose(self, Py_ssize_t new_size) except *

    cpdef void set_all_to(self, double val) except *

    cpdef void set_all_with(self, object fn_new_val) except *

    cpdef void empty(self)  except *

    cpdef void trim_at(self, Py_ssize_t pos, Py_ssize_t amt) except *

    cpdef void extend_at(self, Py_ssize_t pos, Py_ssize_t amt) except *

    cpdef void extend(self, Py_ssize_t amt) except *

    cpdef void append(self, double val)  except *

    cpdef void insert_at(self, Py_ssize_t pos, double val) except *

    cdef double pop(self) except *

    cdef double pop_at(self, Py_ssize_t pos) except *

    cpdef void concatenate(self, DoubleArray arr) except *

    cpdef void embed_at(self, Py_ssize_t pos, DoubleArray arr) except *

cdef class IntpArray(Copyable):
    cdef public Py_ssize_t capacity
    cdef public Py_ssize_t[::1] view

    cpdef void copy_from(self, object obj) except *

    cpdef void repurpose_like(self, IntpArray other) except *

    cpdef void repurpose(self, Py_ssize_t new_size) except *

    cpdef void set_all_to(self, Py_ssize_t val) except *

    cpdef void set_all_with(self, object fn_new_val) except *

    cpdef void empty(self)  except *

    cpdef void trim_at(self, Py_ssize_t pos, Py_ssize_t amt) except *

    cpdef void extend(self, Py_ssize_t amt) except *

    cpdef void extend_at(self, Py_ssize_t pos, Py_ssize_t amt) except *

    cpdef void append(self, Py_ssize_t val)  except *

    cpdef void insert_at(self, Py_ssize_t pos, Py_ssize_t val) except *

    cdef Py_ssize_t pop(self) except *

    cdef Py_ssize_t pop_at(self, Py_ssize_t pos) except *

    cpdef void concatenate(self, IntpArray arr) except *

    cpdef void embed_at(self, Py_ssize_t pos, IntpArray arr) except *
