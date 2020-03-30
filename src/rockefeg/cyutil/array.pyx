cimport cython
from cpython.mem cimport PyMem_Free, PyMem_Malloc
from cpython.ref cimport Py_INCREF, Py_DECREF, PyObject

import numpy as np

@cython.warn.undeclared(True)
@cython.auto_pickle(False)
cdef class ObjectArray():

    def __init__(self, object base = None):
        cdef object nparr
        cdef tuple shape
        cdef object[::1] base_view
        cdef Py_ssize_t index

        base_view = base

        if base is None:
            shape = (0,)
        else:
            self.view = base
            shape = (self.view.shape[0],)

        # Make a copy of view with a new numpy exporting object.
        nparr = np.ndarray(shape, 'O')
        self.view = nparr
        self.capacity = self.view.shape[0]

        if base is not None:
            # Copy base data into new view if base exist (not None).
            for index in range(self.view.shape[0]):
                self.view[index] = base_view[index]


    def __reduce__(self):
        cdef object nparr
        cdef tuple shape
        cdef object[::1] nparr_view
        cdef Py_ssize_t index

        shape = (self.view.shape[0],)

        nparr = np.ndarray(shape, 'O')
        nparr_view = nparr
        for index in range(len(self)):
            nparr_view[index] = self.view[index]

        return self.__class__, (nparr,)

    def __len__(self):
        return self.view.shape[0]

    def __del__(self):
        self.empty()
        self.remove_extra_refs()


    cpdef void set_all_to(self, object obj) except *:
        cdef Py_ssize_t index

        if self.view is not None:
            for index in range(self.view.shape[0]):
                self.view[index] = obj

    cpdef void set_all_with(self, object fn_new_obj) except *:
        cdef Py_ssize_t index

        if self.view is not None:
            for index in range(self.view.shape[0]):
                self.view[index] = fn_new_obj()

    cpdef void shrink_to_fit(self) except *:
        cdef object nparr
        cdef tuple shape
        cdef object[::1] nparr_view
        cdef Py_ssize_t index

        shape = (len(self),)

        # Create new view, and copy data to it.
        nparr = np.ndarray(shape, 'O')
        nparr_view = nparr
        for index in range(len(self)):
            nparr_view[index] = self.view[index]

        # Remove extra references
        self.empty()
        self.remove_extra_refs()

        # Update view and capacity
        self.view = nparr
        self.capacity = len(self)

    cpdef void repurpose_like(self, ObjectArray other) except *:
        self.repurpose(len(other))

    cpdef void repurpose(self, Py_ssize_t new_size) except *:
        cdef object nparr
        cdef object[::1] nparr_view
        cdef Py_ssize_t index
        cdef tuple shape

        if self.capacity < new_size:
            # Make a new view with increased capacity, if the current
            # capacity is too small.

            # Exponential growth pattern.
            if 2 * self.capacity < new_size:
                shape = (new_size,)
            else:
                shape = (2 * self.capacity,)

            # Create new view, and copy data to it.
            nparr = np.ndarray(shape, 'O')
            nparr_view = nparr
            for index in range(len(self)):
                nparr_view[index] = self.view[index]

            # Remove extra references
            self.empty()
            self.remove_extra_refs()

            # Update view and capacity
            self.view = nparr
            self.capacity = len(self)

        # Reshape view for new purpose.
        self.view.shape[0] = new_size

    cpdef void empty(self)  except *:
        self.repurpose(0)

    cpdef void remove_extra_refs(self) except *:
        cdef Py_ssize_t size
        cdef Py_ssize_t index

        size = len(self)
        self.repurpose(self.capacity)

        for index in range(size, len(self)):
            self.view[index] = None

        self.repurpose(size)

    cpdef void trim_at(
            self,
            Py_ssize_t pos,
            Py_ssize_t amt,
            bint reuses_refs = True
            ) except *:
        cdef ObjectArray prev_self_copy
        cdef Py_ssize_t new_size
        cdef Py_ssize_t index
        cdef Py_ssize_t raw_pos
        cdef Py_ssize_t stop_pos
        cdef PyObject** reused_objs

        raw_pos = pos

        if pos < -len(self):
            pos += len(self)

        stop_pos = pos + amt

        if raw_pos < -len(self) or raw_pos >= len(self):
            raise(
                IndexError(
                    "Trim position (pos = {raw_pos}) is out of range "
                    "for this array of size (len(self) = {self.view.shape[0]})"
                    .format(**locals()) ))

        if amt < 0:
            raise(
                IndexError(
                    "The trim amount (amt = {amt}) must be non-negative."
                    .format(**locals()) ))


        if stop_pos > len(self):
            raise(
                IndexError(
                    "The trim range ([pos, pos + amt) =  [{pos}, {stop_pos})) "
                    "using the amount (amt = {amt}) is out of range "
                    "for this array of size (len(self) = {self.view.shape[0]})"
                    .format(**locals()) ))

        if amt == 0:
            return

        reused_objs = NULL

        # Get the new size.
        new_size = len(self) - amt

        # Copy references to reused objects.
        if reuses_refs:
            reused_objs = (
                <PyObject**>PyMem_Malloc(sizeof(PyObject*) * amt))

            if reused_objs == NULL:
                raise MemoryError()

            for index in range(amt):
                reused_objs[index] = <PyObject*> self.view[index + pos]
                Py_INCREF(self.view[index + pos])

        # Shift values after position (pos)
        for index in range(len(self) - pos - amt):
            self.view[index+pos] = self.view[index+pos+amt]

        # Set trimmed objects.
        for index in range(amt):
            if reuses_refs:
                self.view[-index] = <object>reused_objs[index]
                Py_DECREF(self.view[-index])
            else:
                self.view[-index] = None

        if reused_objs != NULL:
            PyMem_Free(reused_objs)

        # Reshape view;
        self.view.shape[0] = new_size


    cpdef void extend_at(
            self,
            Py_ssize_t pos,
            Py_ssize_t amt,
            bint reuses_refs = True
            ) except *:
        cdef ObjectArray prev_self_copy
        cdef Py_ssize_t new_size
        cdef Py_ssize_t index
        cdef PyObject** reused_objs

        if pos < -len(self) or pos > len(self):
            raise(
                IndexError(
                    "Extend position (pos = {pos}) is out of range "
                    "for this array of size (len(self) = {self.view.shape[0]})"
                    .format(**locals()) ))

        if pos < -len(self):
            pos += len(self)

        if amt < 0:
            raise(
                IndexError(
                    "The extend amount (amt = {amt}) must be non-negative."
                    .format(**locals()) ))

        if amt == 0:
            return

        reused_objs = NULL

        # Get the new size.
        new_size = len(self) + amt

        if self.capacity < new_size:
            # Increase capacity if it is too small.

            # Increase size to capacity.
            self.view.shape[0] = self.capacity

            # Make a shallow copy of self with capacity.
            prev_self_copy = ObjectArray(None)
            prev_self_copy.repurpose_like(self)
            for index in range(len(self)):
                prev_self_copy.view[index] = self.view[index]

            # Get a higher capacity view.
            self.repurpose(new_size)

            # Copy data back to higher capacity view.
            for index in range(len(prev_self_copy)):
                self.view[index] = prev_self_copy.view[index]


        # Reshape view;
        self.view.shape[0] = new_size

        # Copy references to reused objects.
        if reuses_refs:
            reused_objs = (
                <PyObject**>PyMem_Malloc(sizeof(PyObject*) * amt))

            if reused_objs == NULL:
                raise MemoryError()

            for index in range(amt):
                reused_objs[index] = <PyObject*> self.view[-index]
                Py_INCREF(self.view[-index])

        # Shift values after position (pos).
        for index in range(new_size-pos-amt):
            self.view[-index-1] = self.view[-index - amt-1]

        # Set objects in extension gap.
        for index in range(amt):
            if reuses_refs:
                self.view[index+pos] = <object>reused_objs[index]
                Py_DECREF(self.view[index+pos])
            else:
                self.view[index] = None

        if reused_objs != NULL:
            PyMem_Free(reused_objs)

    cpdef void extend(self, Py_ssize_t amt, bint reuses_refs = True) except *:
        self.extend_at(len(self), amt, reuses_refs)

    cpdef void append(self, object obj, bint reuses_refs = True)  except *:
        self.extend_at(len(self), 1, reuses_refs)
        self.view[-1] = obj

    cpdef void insert_at(
            self,
            Py_ssize_t pos,
            object obj,
            bint reuses_refs = True
            )  except *:
        self.extend_at(pos, 1, reuses_refs)
        self.view[pos] = obj

    cdef object pop(self, bint reuses_refs = True):
        cdef object obj

        obj = self.view[-1]
        self.trim_at(-1, 1, reuses_refs)

        return obj


    cdef object pop_at(self, Py_ssize_t pos, bint reuses_refs = True):
        cdef object obj

        obj = self.view[pos]
        self.trim_at(pos, 1, reuses_refs)

        return obj

@cython.warn.undeclared(True)
@cython.auto_pickle(False)
cdef class SheddingObjectArray(ObjectArray):
    cpdef void repurpose(self, Py_ssize_t new_size) except *:
        ObjectArray.repurpose(self, new_size)
        self.remove_extra_refs()

    cpdef void trim_at(
            self,
            Py_ssize_t pos,
            Py_ssize_t amt,
            bint reuses_refs = False
            ) except *:
        ObjectArray.trim_at(self, pos, amt, reuses_refs)


    cpdef void extend_at(
            self,
            Py_ssize_t pos,
            Py_ssize_t amt,
            bint reuses_refs = False
            ) except *:
        ObjectArray.extend_at(self, pos, amt, reuses_refs)

    cpdef void extend(self, Py_ssize_t amt, bint reuses_refs = False) except *:
        self.extend_at(len(self), amt, reuses_refs)

    cpdef void append(self, object obj, bint reuses_refs = False)  except *:
        self.extend_at(len(self), 1, reuses_refs)
        self.view[-1] = obj

    cpdef void insert_at(
            self,
            Py_ssize_t pos,
            object obj,
            bint reuses_refs = False
            )  except *:
        self.extend_at(pos, 1, reuses_refs)
        self.view[pos] = obj

    cdef object pop(self, bint reuses_refs = False):
        cdef object obj

        obj = self.view[-1]
        self.trim_at(-1, 1, reuses_refs)

        return obj


    cdef object pop_at(self, Py_ssize_t pos, bint reuses_refs = False):
        cdef object obj

        obj = self.view[pos]
        self.trim_at(pos, 1, reuses_refs)

        return obj

@cython.warn.undeclared(True)
@cython.auto_pickle(False)
cdef class DoubleArray(Copyable):
    def __cinit__(self):
        cdef object nparr

        nparr = np.ndarray((0,), 'd')
        self.view = nparr
        self.capacity = self.view.shape[0]

    def __init__(self, object base):
        cdef object nparr
        cdef tuple shape
        cdef double[::1] base_view
        cdef Py_ssize_t index

        base_view = base

        if base is None:
            shape = (0, )
        else:
            self.view = base
            shape = (self.view.shape[0],)

        # Make a copy of view with a new numpy exporting object.
        nparr = np.ndarray(shape, 'd')
        self.view = nparr
        self.capacity = self.view.shape[0]

        if base is not None:
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

    cpdef void copy_from(self, object obj) except *:
        cdef DoubleArray other
        cdef Py_ssize_t index

        other = <DoubleArray?> obj

        self.repurpose(len(other))
        for index in range(len(self)):
            self.view[index] = other.view[index]

    cpdef void repurpose_like(self, DoubleArray other) except *:
        self.repurpose(len(other))

    cpdef void repurpose(self, Py_ssize_t new_size) except *:
        cdef object nparr
        cdef tuple shape

        if self.capacity < new_size:
            # or make a new view with increased capacity, if the current
            # capacity is too small.

            if 2 * self.capacity < new_size:
                shape = (new_size,)
            else:
                shape = (2 * self.capacity,)
            nparr = np.ndarray(shape, 'd')

            # Update view and capacity
            self.view = nparr
            self.capacity = len(self)

        # Reshape view for new purpose.
        self.view.shape[0] = new_size

    cpdef void set_all_to(self, double val) except *:
        cdef Py_ssize_t index

        if self.view is not None:
            for index in range(len(self)):
                self.view[index] = val

    cpdef void set_all_with(self, object fn_new_val) except *:
        cdef Py_ssize_t index

        if self.view is not None:
            for index in range(len(self)):
                self.view[index] = fn_new_val()

    cpdef void empty(self)  except *:
        self.repurpose(0)

    cpdef void trim_at(self, Py_ssize_t pos, Py_ssize_t amt) except *:
        cdef DoubleArray prev_self_copy
        cdef Py_ssize_t new_size
        cdef Py_ssize_t index
        cdef Py_ssize_t raw_pos
        cdef Py_ssize_t stop_pos

        raw_pos = pos

        if pos < -len(self):
            pos += len(self)

        stop_pos = pos + amt

        if raw_pos < -len(self) or raw_pos >= len(self):
            raise(
                IndexError(
                    "Trim position (pos = {raw_pos}) is out of range "
                    "for this array of size (len(self) = {self.view.shape[0]})"
                    .format(**locals()) ))

        if amt < 0:
            raise(
                IndexError(
                    "The trim amount (amt = {amt}) must be non-negative."
                    .format(**locals()) ))


        if stop_pos > len(self):
            raise(
                IndexError(
                    "The trim range ([pos, pos + amt) =  [{pos}, {stop_pos})) "
                    "using the amount (amt = {amt}) is out of range "
                    "for this array of size (len(self) = {self.view.shape[0]})"
                    .format(**locals()) ))

        if amt == 0:
            return


        # Get the new size.
        new_size = len(self) - amt

        # Shift values after position (pos)
        for index in range(len(self) - pos - amt):
            self.view[index+pos] = self.view[index+pos+amt]


        # Reshape view;
        self.view.shape[0] = new_size


    cpdef void extend_at(self, Py_ssize_t pos, Py_ssize_t amt) except *:
        cdef DoubleArray prev_self_copy
        cdef Py_ssize_t new_size
        cdef Py_ssize_t index

        if pos < -len(self) or pos > len(self):
            raise(
                IndexError(
                    "Extend position (pos = {pos}) is out of range "
                    "for this array of size (len(self) = {self.view.shape[0]})"
                    .format(**locals()) ))

        if pos < -len(self):
            pos += len(self)

        if amt < 0:
            raise(
                IndexError(
                    "The extend amount (amt = {amt}) must be non-negative."
                    .format(**locals()) ))

        if amt == 0:
            return

        # Get the new size.
        new_size = len(self) + amt

        if self.capacity < new_size:
            # Increase capacity if it is too small.

            # Make a copy of self.
            prev_self_copy = self.copy()

            # Get a higher capacity view
            # TODO repurpose when axis > 0
            self.repurpose(new_size)

            # Copy data back.
            for index in range(len(prev_self_copy)):
                self.view[index] = prev_self_copy.view[index]


        # Reshape view;
        self.view.shape[0] = new_size

        # Shift values after position (pos).
        for index in range(new_size-pos-amt):
            self.view[-index-1] = self.view[-index - amt-1]

    cpdef void extend(self, Py_ssize_t amt) except *:
        self.extend_at(len(self), amt)

    cpdef void append(self, double val)  except *:
        self.extend_at(len(self), 1)
        self.view[-1] = val

    cpdef void insert_at(self, Py_ssize_t pos, double val) except *:
        self.extend_at(pos, 1)
        self.view[pos] = val

    cdef double pop(self) except *:
        cdef double val

        val = self.view[-1]
        self.trim_at(-1, 1)

        return val


    cdef double pop_at(self, Py_ssize_t pos) except *:
        cdef double val

        val = self.view[pos]
        self.trim_at(pos, 1)

        return val

    cpdef void concatenate(self, DoubleArray arr) except *:
        cdef Py_ssize_t index
        cdef Py_ssize_t start_pos

        start_pos = len(self)
        self.extend_at(start_pos, len(arr))

        for index in range(len(arr)):
            self.view[index + start_pos] = arr.view[index]


    cpdef void embed_at(self, Py_ssize_t pos, DoubleArray arr) except *:
        cdef Py_ssize_t index
        cdef Py_ssize_t start_pos

        start_pos = pos
        self.extend_at(pos, len(arr))

        for index in range(len(arr)):
            self.view[index + start_pos] = arr.view[index]




@cython.warn.undeclared(True)
@cython.auto_pickle(False)
cdef class IntpArray(Copyable):
    def __cinit__(self):
        cdef object nparr

        nparr = np.ndarray((0,), np.intp)
        self.view = nparr
        self.capacity = self.view.shape[0]

    def __init__(self, object base):
        cdef object nparr
        cdef tuple shape
        cdef Py_ssize_t[::1] base_view
        cdef Py_ssize_t index

        base_view = base

        if base is None:
            shape = (0, )
        else:
            self.view = base
            shape = (self.view.shape[0],)

        # Make a copy of view with a new numpy exporting object.
        nparr = np.ndarray(shape, np.intp)
        self.view = nparr
        self.capacity = self.view.shape[0]

        if base is not None:
            # Copy base data into new view if base exist (not None).
            for index in range(self.view.shape[0]):
                self.view[index] = base_view[index]

    def __reduce__(self):
        cdef object nparr
        cdef tuple shape
        cdef Py_ssize_t[::1] nparr_view
        cdef Py_ssize_t index

        shape = (self.view.shape[0],)

        nparr = np.ndarray(shape, np.intp)
        nparr_view = nparr
        for index in range(len(self)):
            nparr_view[index] = self.view[index]

        return self.__class__, (nparr,)

    def __len__(self):
        return self.view.shape[0]

    cpdef void copy_from(self, object obj) except *:
        cdef IntpArray other
        cdef Py_ssize_t index

        other = <IntpArray?> obj

        self.repurpose(len(other))
        for index in range(len(self)):
            self.view[index] = other.view[index]

    cpdef void repurpose_like(self, IntpArray other) except *:
        self.repurpose(len(other))

    cpdef void repurpose(self, Py_ssize_t new_size) except *:
        cdef object nparr
        cdef tuple shape

        if self.capacity < new_size:
            # or make a new view with increased capacity, if the current
            # capacity is too small.

            if 2 * self.capacity < new_size:
                shape = (new_size,)
            else:
                shape = (2 * self.capacity,)
            nparr = np.ndarray(shape, np.intp)

            # Update view and capacity
            self.view = nparr
            self.capacity = len(self)

        # Reshape view for new purpose.
        self.view.shape[0] = new_size

    cpdef void set_all_to(self, Py_ssize_t val) except *:
        cdef Py_ssize_t index

        if self.view is not None:
            for index in range(len(self)):
                self.view[index] = val

    cpdef void set_all_with(self, object fn_new_val) except *:
        cdef Py_ssize_t index

        if self.view is not None:
            for index in range(len(self)):
                self.view[index] = fn_new_val()

    cpdef void empty(self)  except *:
        self.repurpose(0)

    cpdef void trim_at(self, Py_ssize_t pos, Py_ssize_t amt) except *:
        cdef IntpArray prev_self_copy
        cdef Py_ssize_t new_size
        cdef Py_ssize_t index
        cdef Py_ssize_t raw_pos
        cdef Py_ssize_t stop_pos

        raw_pos = pos

        if pos < -len(self):
            pos += len(self)

        stop_pos = pos + amt

        if raw_pos < -len(self) or raw_pos >= len(self):
            raise(
                IndexError(
                    "Trim position (pos = {raw_pos}) is out of range "
                    "for this array of size (len(self) = {self.view.shape[0]})"
                    .format(**locals()) ))

        if amt < 0:
            raise(
                IndexError(
                    "The trim amount (amt = {amt}) must be non-negative."
                    .format(**locals()) ))


        if stop_pos > len(self):
            raise(
                IndexError(
                    "The trim range ([pos, pos + amt) =  [{pos}, {stop_pos})) "
                    "using the amount (amt = {amt}) is out of range "
                    "for this array of size (len(self) = {self.view.shape[0]})"
                    .format(**locals()) ))

        if amt == 0:
            return


        # Get the new size.
        new_size = len(self) - amt

        # Shift values after position (pos)
        for index in range(len(self) - pos - amt):
            self.view[index+pos] = self.view[index+pos+amt]


        # Reshape view;
        self.view.shape[0] = new_size


    cpdef void extend_at(self, Py_ssize_t pos, Py_ssize_t amt) except *:
        cdef IntpArray prev_self_copy
        cdef Py_ssize_t new_size
        cdef Py_ssize_t index

        if pos < -len(self) or pos > len(self):
            raise(
                IndexError(
                    "Extend position (pos = {pos}) is out of range "
                    "for this array of size (len(self) = {self.view.shape[0]})"
                    .format(**locals()) ))

        if pos < -len(self):
            pos += len(self)

        if amt < 0:
            raise(
                IndexError(
                    "The extend amount (amt = {amt}) must be non-negative."
                    .format(**locals()) ))

        if amt == 0:
            return

        # Get the new size.
        new_size = len(self) + amt

        if self.capacity < new_size:
            # Increase capacity if it is too small.

            # Make a copy of self.
            prev_self_copy = self.copy()

            # Get a higher capacity view
            # TODO repurpose when axis > 0
            self.repurpose(new_size)

            # Copy data back.
            for index in range(len(prev_self_copy)):
                self.view[index] = prev_self_copy.view[index]


        # Reshape view;
        self.view.shape[0] = new_size

        # Shift values after position (pos).
        for index in range(new_size-pos-amt):
            self.view[-index-1] = self.view[-index - amt-1]

    cpdef void extend(self, Py_ssize_t amt) except *:
        self.extend_at(len(self), amt)

    cpdef void append(self, Py_ssize_t val)  except *:
        self.extend_at(len(self), 1)
        self.view[-1] = val

    cpdef void insert_at(self, Py_ssize_t pos, Py_ssize_t val) except *:
        self.extend_at(pos, 1)
        self.view[pos] = val

    cdef Py_ssize_t pop(self) except *:
        cdef Py_ssize_t val

        val = self.view[-1]
        self.trim_at(-1, 1)

        return val


    cdef Py_ssize_t pop_at(self, Py_ssize_t pos) except *:
        cdef Py_ssize_t val

        val = self.view[pos]
        self.trim_at(pos, 1)

        return val


    cpdef void concatenate(self, IntpArray arr) except *:
        cdef Py_ssize_t index
        cdef Py_ssize_t start_pos

        start_pos = len(self)
        self.extend_at(start_pos, len(arr))

        for index in range(len(arr)):
            self.view[index + start_pos] = arr.view[index]


    cpdef void embed_at(self, Py_ssize_t pos, IntpArray arr) except *:
        cdef Py_ssize_t index
        cdef Py_ssize_t start_pos

        start_pos = pos
        self.extend_at(pos, len(arr))

        for index in range(len(arr)):
            self.view[index + start_pos] = arr.view[index]



