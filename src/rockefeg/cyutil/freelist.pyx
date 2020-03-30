cimport cython

from .array import SheddingObjectArray

@cython.warn.undeclared(True)
cdef inline Py_ssize_t refcnt(object obj) except *:
    return (<_object*>obj)[0].ob_refcnt

@cython.warn.undeclared(True)
cdef inline bint is_free(object obj) except *:
    print((<_object*>obj)[0].ob_refcnt)
    return (<_object*>obj)[0].ob_refcnt <= 2

@cython.warn.undeclared(True)
cdef inline void compact(SheddingObjectArray level) except *:
    cdef Py_ssize_t n_objs_found
    cdef Py_ssize_t obj_id

    n_objs_found = 0

    # Move not-None objects to front of list.
    for obj_id in range(len(level)):
        if level.view[obj_id] is not None:
            level.view[n_objs_found] = level.view[obj_id]
            n_objs_found += 1

    # Derefence the rest of the list.
    for obj_id in range(n_objs_found, len(level)):
        level.view[obj_id] = None

    # Trim dereferences from the list.
    level.trim(n_objs_found, len(level) - n_objs_found)

def py_compact(obj):
    compact(<SheddingObjectArray?> obj)

@cython.warn.undeclared(True)
cdef class Freelist():
    def __init__(self,
            object fn_new_free_object,
            Py_ssize_t n_levels = 2,
            Py_ssize_t max_n_objs = 100):

        cdef Py_ssize_t level_id

        if n_levels <= 0:
            raise (
                ValueError(
                    "The number of levels (n_levels = {n_levels} "
                    "must be positive."
                    .format(**locals())))

        if max_n_objs <= 0:
            raise (
                ValueError(
                    "The maximum number of objects (max_n_objs = {max_n_objs} "
                    "must be positive."
                    .format(**locals())))

        self.m_n_objs = 0
        self.m_max_n_objs = max_n_objs
        self.m_fn_new_free_object = fn_new_free_object
        self.m_levels = [None] * n_levels
        for level_id in range(n_levels):
            self.m_levels[level_id] = SheddingObjectArray(None)

        self.m_free_objs = SheddingObjectArray(None)

    def __len__(self):
        return self.m_n_objs

    def __reduce__(self):
        self.__class__, (self.fn_new_free_object()(),)

    cpdef Py_ssize_t n_levels(self) except *:
        return len(self.m_levels)

    cpdef Py_ssize_t n_objs(self) except *:
        return self.m_n_objs

    cpdef Py_ssize_t max_n_obs(self) except *:
        return self.m_max_n_obs

    cpdef object fn_new_free_object(self):
        return self.m_fn_new_free_object

    cpdef object free_obj(self):
        cdef object free_obj
        cdef Py_ssize_t level_id
        cdef Py_ssize_t obj_id
        cdef Py_ssize_t extra_refcnt
        cdef SheddingObjectArray level
        cdef Py_ssize_t freed_level_id
        cdef SheddingObjectArray next_level

        free_obj = None

        level = self.m_levels[0]
        if len(self.m_free_objs) == 0:
            # Find free objects and update levels if no
            # free object is available.

            for level_id in range(self.n_levels()):
                # Until free objects are found, search each level
                # for free objects.

                level = self.m_levels[level_id]
                for obj_id in range(len(level)):
                    if is_free(level.view[obj_id]):
                        self.m_free_objs.append(level.view[obj_id])

                        # Mark freed position in level as None
                        # instead of plucking to derefence.
                        level.view[obj_id] = None

                # Free objects were found.
                if len(self.m_free_objs) > 0:
                    freed_level_id = level_id
                    break
                else:
                    freed_level_id = self.n_levels() - 1


            # Move non-free objects up a level to represent that these objects
            # are less likely to be free in the future.
            for level_id in range(freed_level_id,-1, -1):

                level = self.m_levels[level_id]


                if level_id != self.n_levels() - 1:
                    # If the current level is not the highest level,
                    # then move non-marked objects in level to a higher level;

                    next_level = self.m_levels[level_id + 1]

                    # Set moved position to None instead of
                    # plucking to derefence.
                    for obj_id in range(len(level)):
                        if level.view[obj_id] is not None:
                            next_level.append(level.view[obj_id])
                            level.view[obj_id] = None

                    level.empty()
                else:
                    # or, if the current level is the highest level, then
                    # compact it (Remove None references).
                    compact(level)




        if len(self.m_free_objs) > 0:
            # If a free object is available in the free object list,
            # add the object to the first level of maybe-free objects
            # and later return it;

            free_obj = self.m_free_objs.pop()
            self.m_levels[0].append(free_obj)
        else:
            # Or,  If a free object is available in the free object list
            # even after processing all levels of maybe-free objects,
            # then we create a free object using a factory method.

            free_obj = self.fn_new_free_object()()
            if not is_free(free_obj):
                extra_refcnt = refcnt(free_obj) - 2
                raise (
                    RuntimeError(
                        "The factory method "
                        "(self.m_fn_new_free_object = "
                        "{self.m_fn_new_free_object}) did not create a "
                        "free object. There are "
                        "(extra_refcnt = {extra_refcnt}) extra references "
                        "to the returned object (free_obj = {free_obj})."
                        .format(**locals()) ))

            self.m_levels[0].append(free_obj)
            if self.m_n_objs < self.max_n_objs():
                self.m_n_objs += 1
            else:
                # If the number of objects in the freelist is maxed out,
                # then we delete a maybe-free object from a high level, since
                # high level objects are not likely to be free soon.
                self.m_levels[-1].pluck(-1)

        return free_obj

