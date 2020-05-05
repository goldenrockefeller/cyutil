cimport cython
import numpy as np

cdef extern from "object.h":
    struct _object:
        Py_ssize_t ob_refcnt

cdef inline bint is_free(obj) except *:
    return (<_object*>obj)[0].ob_refcnt <= 2

cdef enum:
    MIN_CAPACITY_IN_FREELIST = 32
    MAX_SIZE_IN_FREELIST = 32000

cdef list double_array_freelists = []
cdef list intp_array_freelists = []

cdef Py_ssize_t capacity = MIN_CAPACITY_IN_FREELIST
double_array_freelists.append(Freelist(capacity))
intp_array_freelists.append(Freelist(capacity))
while capacity < MAX_SIZE_IN_FREELIST:
    capacity *= 2
    double_array_freelists.append(Freelist(capacity))
    intp_array_freelists.append(Freelist(capacity))

@cython.warn.undeclared(True)
cdef class Freelist:
    cdef public list objs
    cdef public Py_ssize_t obj_capacity
    cdef public Py_ssize_t n_free_objs

    def __init__(self, obj_capacity):
        self.objs = []
        self.n_free_objs = 0
        self.obj_capacity = obj_capacity

    cpdef void collect_free(self) except *:
        cdef Py_ssize_t i
        cdef object tmp

        for i in range(self.n_free_objs, len(self.objs)):
            if is_free(self.objs[i]):
                tmp = self.objs[self.n_free_objs]
                self.objs[self.n_free_objs] = self.objs[i]
                self.objs[i] = tmp
                self.n_free_objs += 1

    cpdef free_obj(self):
        cdef Py_ssize_t free_obj_id

        if self.n_free_objs == 0:
            raise IndexError("There are no free objects in this freelist.")

        free_obj_id = self.n_free_objs - 1
        self.n_free_objs -= 1

        return self.objs[free_obj_id]

@cython.warn.undeclared(True)
@cython.auto_pickle(False)
cdef class DoubleArray:

    def __init__(self, base, bint copies = True):
        cdef object nparr
        cdef tuple shape
        cdef double[::1] base_view
        cdef Py_ssize_t index

        if base is None:
            raise ValueError("(base) can not be None.")

        base_view = base

        self.view = base
        shape = (self.view.shape[0],)

        # Make a copy of view with a new numpy exporting object.
        nparr = np.ndarray(shape, 'd')
        self.view = nparr
        self.capacity = self.view.shape[0]

        if base is not None and copies:
            # Copy base data into new view if base exist (not None).
            for index in range(self.view.shape[0]):
                self.view[index] = base_view[index]

    def __reduce__(self):
        cdef object nparr
        cdef tuple shape
        cdef double[::1] nparr_view
        cdef Py_ssize_t index

        shape = (self.view.shape[0],)

        nparr = np.ndarray(shape, 'd')
        nparr_view = nparr
        for index in range(len(self)):
            nparr_view[index] = self.view[index]

        return self.__class__, (nparr,)

    def __len__(self):
        return self.view.shape[0]

    @staticmethod
    def freelists():
        global double_array_freelists
        return double_array_freelists

    cpdef copy(self, copy_obj = None):
        cdef DoubleArray new_arr

        cdef Py_ssize_t i

        if copy_obj is None:
            new_arr = new_DoubleArray(len(self))
        else:
            new_arr = copy_obj

        for i in range(len(self)):
            new_arr.view[i] = self.view[i]

        return new_arr

    cpdef void set_all_to(self, double val) except *:
        cdef Py_ssize_t i

        for i in range(len(self)):
            self.view[i] = val

@cython.warn.undeclared(True)
cdef DoubleArray new_DoubleArray(Py_ssize_t size):
    global MIN_CAPACITY_IN_FREELIST
    global MAX_SIZE_IN_FREELIST
    global double_array_freelists

    cdef Py_ssize_t capacity
    cdef Py_ssize_t freelist_id
    cdef Py_ssize_t i
    cdef Freelist freelist
    cdef DoubleArray new_arr

    if size < 0:
        raise (
            ValueError(
                "The array size (size = {size}) must be non-negative."
                .format(**locals())))

    if size > MAX_SIZE_IN_FREELIST:
        new_arr = DoubleArray.__new__(DoubleArray)
        new_arr.view = np.ndarray((size,), 'd')
        new_arr.capacity = size
        return new_arr

    capacity = MIN_CAPACITY_IN_FREELIST
    freelist_id = 0

    while size > capacity:
        freelist_id += 1
        capacity *= 2

    freelist = double_array_freelists[freelist_id]

    # Collect free objects if the freelist is empty.
    if freelist.n_free_objs == 0:
        freelist.collect_free()

        # After collection, grow the freelist if not enough objects
        # were freed.
        if freelist.n_free_objs < max(len(freelist.objs) // 2, 1):
            freelist.objs = [None] * max(2 * len(freelist.objs), 1)
            for i in range(len(freelist.objs)):
                freelist.objs[i] = DoubleArray.__new__(DoubleArray)
                freelist.objs[i].view = np.ndarray((capacity,), 'd')
                freelist.objs[i].capacity = capacity
                # freelist.objs[i] = DoubleArray(np.ndarray((capacity,), 'd'))
            freelist.n_free_objs = len(freelist.objs)

    # Take new object from the freelist and resize the object.
    new_arr = freelist.free_obj()
    new_arr.view.shape[0] = size

    return new_arr
















