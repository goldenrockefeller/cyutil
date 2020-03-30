cimport cython
from .array cimport SheddingObjectArray

cdef extern from "object.h":
    struct _object:
        Py_ssize_t ob_refcnt


cdef class Freelist():
    cdef public Py_ssize_t m_n_objs
    cdef public Py_ssize_t m_max_n_objs
    cdef public object m_fn_new_free_object
    cdef public list m_levels
    cdef public SheddingObjectArray m_free_objs

    cpdef Py_ssize_t n_levels(self) except *

    cpdef Py_ssize_t n_objs(self) except *

    cpdef Py_ssize_t max_n_obs(self) except *

    cpdef object fn_new_free_object(self)

    cpdef object free_obj(self)