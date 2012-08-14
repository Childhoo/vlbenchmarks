classdef repeatabilityBenchmark < benchmarks.genericBenchmark
  %REPEATABILITYTEST Calc repeatability score of aff. cov. detectors test.
  %   repeatabilityTest(resultsStorage,'OptionName',optionValue,...)
  %   constructs an object for calculating repeatability score. 
  %
  %   Score is calculated when method runTest is invoked.
  %
  %   Options:
  %
  %   OverlapError :: [0.4]
  %   Maximal overlap error of ellipses to be considered as
  %   correspondences.
  %
  %   NormaliseFrames :: [true]
  %   Normalise the frames to constant scale (defaults is true for detector
  %   repeatability tests, see Mikolajczyk et. al 2005).
  %
  %   CacheReprojectedFrames :: [false]
  %   Store reprojected frames and best matches. When false saves amount of
  %   data stored in cache but does not allow to plot matches afterwards.
  %
  
  properties
    opts                % Local options of repeatabilityTest
  end
  
  properties(Constant)
    defOverlapError = 0.4;
    defNormaliseFrames = true;
    defCacheReprojectedFrames = false;
    keyPrefix = 'repeatability';
    repFramesKeyPrefix = 'repFrames';
  end
  
  methods
    function obj = repeatabilityBenchmark(varargin)
      import benchmarks.*;
      obj.benchmarkName = 'repeatability';
      
      obj.opts.overlapError = repeatabilityBenchmark.defOverlapError;
      obj.opts.normaliseFrames = repeatabilityBenchmark.defNormaliseFrames;
      obj.opts.cacheReprojectedFrames = repeatabilityBenchmark.defCacheReprojectedFrames;
      if numel(varargin) > 0
        obj.opts = helpers.vl_argparse(obj.opts,varargin{:});
      end
      
    end
    
    function [repeatability numCorresp reprojFrames bestMatches] = ...
                testDetector(obj, detector, tf, imageAPath, imageBPath)

      import benchmarks.*;
      import helpers.*;
      
      Log.info(obj.benchmarkName,...
        sprintf('Comparing frames from det. %s and images %s and %s.',...
          detector.detectorName,getFileName(imageAPath),getFileName(imageBPath)));
      
      imageASign = helpers.fileSignature(imageAPath);
      imageBSign = helpers.fileSignature(imageBPath);
      detSign = detector.getSignature();
      keyPrefix = repeatabilityBenchmark.keyPrefix;
      resultsKey = strcat(keyPrefix,detSign,imageASign,imageBSign);
      cachedResults = helpers.DataCache.getData(resultsKey);
      
      if isempty(cachedResults)
        [framesA] = detector.extractFeatures(imageAPath);
        [framesB] = detector.extractFeatures(imageBPath);
      
        [repeatability numCorresp reprojFrames bestMatches] = ... 
          testFeatures(obj,tf,imageAPath, imageBPath,framesA, framesB);
        
        if obj.opts.cacheReprojectedFrames
          results = {repeatability numCorresp reprojFrames bestMatches};
        else
          results = {repeatability numCorresp [] []};
        end
        
        helpers.DataCache.storeData(results, resultsKey);
      else
        [repeatability numCorresp reprojFrames bestMatches] = cachedResults{:};
        Log.debug(obj.benchmarkName,'Results loaded from cache');
      end
      
    end
   
    function [repeatability numCorresp reprojFrames bestMatches] = ... 
                testFeatures(obj, tf, imageAPath, imageBPath, framesA, framesB)
      import benchmarks.helpers.*;
      import helpers.*;
      
      Log.info(obj.benchmarkName,...
        sprintf('Computing repeatability between %d/%d frames.',...
          size(framesA,2),size(framesB,2)));
      
      startTime = tic;
      normFrames = obj.opts.normaliseFrames;
      overlErr = obj.opts.overlapError;
      
      imageA = imread(imageAPath);
      imageB = imread(imageBPath);
      [cropFramesA,cropFramesB,repFramesA,repFramesB] = ...
        cropFramesToOverlapRegion(framesA,framesB,tf,imageA,imageB);

      frameMatches = matchEllipses(repFramesB, cropFramesA,'NormaliseFrames',normFrames);
      bestMatches = findOneToOneMatches(frameMatches,cropFramesA,repFramesB,overlErr);
      numBestMatches = sum(bestMatches ~= 0);
      repeatability = numBestMatches / min(size(cropFramesA,2), size(cropFramesB,2));
      numCorresp = numBestMatches;
      
      reprojFrames = {cropFramesA,cropFramesB,repFramesA,repFramesB};
      
      Log.info(obj.benchmarkName,...
        sprintf('Repeatability: %g \t Num correspondences: %g',...
        repeatability,numCorresp));
      
      timeElapsed = toc(startTime);
      Log.debug(obj.benchmarkName,...
        sprintf('Score between %d/%d frames comp. in %gs',...
        size(framesA,2),size(framesB,2),timeElapsed));
    end
  end 
    
  methods (Static)
      
    function plotFrameMatches(reprojectedFrames, bestMatches,...
                              imageAPath, imageBPath, figA, figB)
      
      imageA = imread(imageAPath);
      imageB = imread(imageBPath);
      
      [cropFramesA,cropFramesB,repFramesA,repFramesB] = reprojectedFrames{:};
      
      figure(figA); 
      imshow(imageA);
      colormap gray ;
      hold on ; vl_plotframe(cropFramesA,'linewidth', 1);
      % Plot the transformed and matched frames from B on A in blue
      vl_plotframe(repFramesB(:,bestMatches~=0),'b','linewidth',1);
      % Plot the remaining frames from B on A in red
      vl_plotframe(repFramesB(:,bestMatches==0),'r','linewidth',1);
      axis equal;
      set(gca,'xtick',[],'ytick',[]);
      title('Reference image detections');

      figure(figB); 
      imshow(imageB) ;
      hold on ; vl_plotframe(framesB,'linewidth', 1); axis equal; axis off;
      %vl_plotframe(framesA_, 'b', 'linewidth', 1) ;
      title('Transformed image detections');
    end
    
  end
  
end

