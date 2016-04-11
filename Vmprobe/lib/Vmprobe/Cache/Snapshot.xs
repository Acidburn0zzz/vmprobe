#ifdef __cplusplus
extern "C" {
#endif

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#ifdef __cplusplus
}
#endif

#include "snapshot.h"
#include "summary.h"

#include <stdexcept>


MODULE = Vmprobe::Cache::Snapshot        PACKAGE = Vmprobe::Cache::Snapshot
 
PROTOTYPES: ENABLE


SV *
_take_mincore(path_sv, total_files_sv, total_pages_sv)
        SV *path_sv
        SV *total_files_sv
        SV *total_pages_sv
    CODE:
        char *path_p;
        size_t path_len;
        SV *output;

        path_len = SvCUR(path_sv);
        path_p = SvPV(path_sv, path_len);

        std::string path(path_p, path_len);

        try {
            vmprobe::cache::snapshot::builder b;

            b.crawl(path);

            sv_setuv(total_pages_sv, b.total_pages_crawled);
            sv_setuv(total_files_sv, b.total_files_crawled);
            output = newSVpvn(b.buf.data(), b.buf.size());
        } catch(std::runtime_error &e) {
            croak(e.what());
        }

        RETVAL = output;
    OUTPUT:
        RETVAL



SV *
_take_pagemap(path_sv, bits_sv, total_files_sv, total_pages_sv)
        SV *path_sv
        SV *bits_sv
        SV *total_files_sv
        SV *total_pages_sv
    CODE:
        char *path_p;
        size_t path_len;

        AV *results_av;
        size_t num_bits;


        SvGETMAGIC(bits_sv);
        if ((!SvROK(bits_sv)) || (SvTYPE(SvRV(bits_sv)) != SVt_PVAV) || ((num_bits = av_top_index((AV *)SvRV(bits_sv))) < 0)) {
            XSRETURN_UNDEF;
        }
        num_bits++; // top_index is one less than length

        results_av = (AV *)sv_2mortal((SV *)newAV());


        path_len = SvCUR(path_sv);
        path_p = SvPV(path_sv, path_len);

        std::string path(path_p, path_len);

        try {
            vmprobe::cache::snapshot::pagemap_builder b;
            std::string snap;

            for (size_t i=0; i < num_bits; i++) {
                uint64_t bit = SvUV(*av_fetch((AV *)SvRV(bits_sv), i, 0));

                // note this "54" overloading hack prevents us from accessing some of the internal kernel bits 
                if (bit > 54) b.register_pagemap_bit(bit);
                else b.register_kpageflags_bit(bit);
            }

            b.crawl(path);

            sv_setuv(total_files_sv, b.total_files_crawled);
            sv_setuv(total_pages_sv, b.total_pages_crawled);

            for (size_t i=0; i < num_bits; i++) {
                uint64_t bit = SvUV(*av_fetch((AV *)SvRV(bits_sv), i, 0));

                if (bit > 54) snap = b.get_pagemap_snapshot(bit);
                else snap = b.get_kpageflags_snapshot(bit);

                av_push(results_av, newSVpv(snap.data(), snap.size()));
            }
        } catch(std::runtime_error &e) {
            croak(e.what());
        }

        RETVAL = newRV((SV *)results_av);;
    OUTPUT:
        RETVAL



void
restore(path_sv, snapshot_sv)
        SV *path_sv
        SV *snapshot_sv
    CODE:
        char *path_p;
        size_t path_len;
        char *snapshot_p;
        size_t snapshot_len;

        path_len = SvCUR(path_sv);
        path_p = SvPV(path_sv, path_len);
        snapshot_len = SvCUR(snapshot_sv);
        snapshot_p = SvPV(snapshot_sv, snapshot_len);

        std::string path(path_p, path_len);

        try {
            vmprobe::cache::snapshot::restore(path, snapshot_p, snapshot_len);
        } catch(std::runtime_error &e) {
            croak(e.what());
        }


SV *
summarize(snapshot_sv, buckets)
        SV *snapshot_sv
        int buckets
    INIT:
        char *snapshot_p;
        size_t snapshot_len;

        snapshot_len = SvCUR(snapshot_sv);
        snapshot_p = SvPV(snapshot_sv, snapshot_len);

        AV *results;
        results = (AV *) sv_2mortal ((SV *) newAV ());

    CODE:
        std::vector<vmprobe::cache::snapshot::summary::builder> s;

        s.emplace_back(std::string(""), buckets);

        try {
            vmprobe::cache::snapshot::summary::summarize(snapshot_p, snapshot_len, s);
        } catch(std::runtime_error &e) {
            croak(e.what());
        }

        for (auto &bucket : s.back().buckets) {
            HV *rh = (HV *) sv_2mortal ((SV *) newHV());

            hv_store(rh, "num_pages", 9, newSVnv(bucket.num_pages), 0);
            hv_store(rh, "num_resident", 12, newSVnv(bucket.num_resident), 0);
            hv_store(rh, "num_files", 9, newSVnv(bucket.num_files), 0);

            hv_store(rh, "start_filename", 14, newSVpvn(bucket.start_filename, bucket.start_filename_len), 0);
            hv_store(rh, "start_page_offset", 17, newSVnv(bucket.start_page_offset), 0);

            av_push(results, newRV((SV *)rh)); 
        }

        RETVAL = newRV((SV *)results);
    OUTPUT:
        RETVAL




SV *
delta(before_sv, after_sv)
        SV *before_sv
        SV *after_sv
    CODE:
        char *before_p;
        size_t before_len;
        char *after_p;
        size_t after_len;
        SV *output;

        before_len = SvCUR(before_sv);
        before_p = SvPV(before_sv, before_len);
        after_len = SvCUR(after_sv);
        after_p = SvPV(after_sv, after_len);

        try {
            vmprobe::cache::snapshot::builder b;

            b.delta(before_p, before_len, after_p, after_len);

            output = newSVpvn(b.buf.data(), b.buf.size());
        } catch(std::runtime_error &e) {
            croak(e.what());
        }

        RETVAL = output;
    OUTPUT:
        RETVAL
