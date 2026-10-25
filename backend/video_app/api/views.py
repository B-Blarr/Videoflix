"""Views for the video list, the HLS files and the thumbnails."""

from pathlib import Path

from django.conf import settings
from django.http import FileResponse, Http404
from django.shortcuts import get_object_or_404
from django.views.static import serve
from rest_framework import generics
from rest_framework.views import APIView

from video_app.models import Video
from video_app.utils import hls_file_path, hls_segment_path

from .serializers import VideoSerializer


class VideoListView(generics.ListAPIView):
    """Return the converted videos, newest first and unpaginated."""

    queryset = Video.objects.filter(status=Video.Status.DONE)
    serializer_class = VideoSerializer


class HLSPlaylistView(APIView):
    """Serve the HLS playlist of one video in one resolution."""

    def get(self, request, movie_id, resolution):
        """Return the m3u8 playlist, or 404 if it is not available."""
        get_object_or_404(Video, pk=movie_id)
        path = hls_file_path(movie_id, resolution, 'index.m3u8')
        if path is None:
            raise Http404
        return FileResponse(
            open(path, 'rb'),
            content_type='application/vnd.apple.mpegurl',
        )


class HLSSegmentView(APIView):
    """Serve a single segment of an HLS stream."""

    def get(self, request, movie_id, resolution, segment):
        """Return one .ts segment as video/MP2T, or 404 if it is missing."""
        get_object_or_404(Video, pk=movie_id)
        path = hls_segment_path(movie_id, resolution, segment)
        if path is None:
            raise Http404
        return FileResponse(open(path, 'rb'), content_type='video/MP2T')


def thumbnail_view(request, path):
    """Serve a thumbnail, also when DEBUG is off.

    Django's static() helper only adds its route while DEBUG is on, so the
    thumbnails would vanish as soon as DEBUG is switched off. serve() joins
    the path safely, a path that leaves the folder answers 400.
    """
    return serve(
        request, path, document_root=Path(settings.MEDIA_ROOT) / 'thumbnails')
