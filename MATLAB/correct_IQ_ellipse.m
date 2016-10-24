%CORRECT_IQ_ELLIPSE correction of an IQ ellipse into an IQ unit circle.
%   Zout = CORRECT_IQ_ELLIPSE(Zin) transforms the complex data Zin into 
%   Zout. Noise aside, Zout should lie on a unit circle.
%   Zout = CORRECT_IQ_ELLIPSE(X, Y) transforms the complex data X+1jY.
%   [X,Y] = CORRECT_IQ_ELLIPSE(...) transforms the complex data to the pair
%   Z = X+1jY
%   [...,A,B] = CORRECT_IQ_ELLIPSE(...) Outputs the transformation matrix
%   and vector that were used to correct the data
%
%   Changes:
%   2016-09-08; Hugo Bergeron; Created file.
%
function [varargout] = correct_IQ_ellipse(varargin)

    %% Deal with two different input formats, complex or separated
    if nargin == 1
        X = real(varargin{1});
        Y = imag(varargin{1});
    elseif nargin == 2
        X = varargin{1};
        Y = varargin{2};
    else
        error('Wrong number of input arguments');
    end
    
    %% Put data in a vector with known dimensions
    N = min(numel(X), numel(Y));
    Xin = reshape(X(1:N),N,1);
    Yin = reshape(Y(1:N),N,1);
    
    %% The fit equation is:
    % axx + 2bxy + cyy + 2dx + 2fy + g = 0, with g = 1
    % We construct and solve the following system of equations. It is
    % derived from nulling the partial derivatives of the sum of squared
    % errors.
    %
    %  sum(xxxx)a + sum(2xxxy)b +  sum(xxyy)c + sum(2xxx)d + sum(2xxy)f =  -sum(xx)
    % sum(2xxxy)a + sum(4xxyy)b + sum(2xyyy)c + sum(4xxy)d + sum(4xyy)f = -sum(2xy)
    %  sum(xxyy)a + sum(2xyyy)b +  sum(yyyy)c + sum(2xyy)d + sum(2yyy)f =  -sum(yy)
    %  sum(2xxx)a +  sum(4xxy)b +  sum(2xyy)c +  sum(4xx)d +  sum(4xy)f =  -sum(2x)
    %  sum(2xxy)a +  sum(4xyy)b +  sum(2yyy)c +  sum(4xy)d +  sum(4yy)f =  -sum(2y)
    %
    
    Dat = [Xin.^2,2*Xin.*Yin,Yin.^2,2*Xin,2*Yin];
    % This is the matrix on the LHS
    A = Dat'*Dat;
    % This is the column vector on the RHS
    D = -sum(Dat)';
    % We solve the system
    X = [linsolve(A, D); 1];
    a = X(1);
    b = X(2);
    c = X(3);
    d = X(4);
    f = X(5);
    g = X(6);
    
    %% We use the equations shown at http://mathworld.wolfram.com/Ellipse.html
    % to extract the center, the semi-axis lengths and angle of the ellipse
    
    % Center of the ellipse
    x0 = (c*d-b*f)/(b*b-a*c);
    y0 = (a*f-b*d)/(b*b-a*c);
    
    % Axis lengths
    aprime = sqrt((2*(a*f*f+c*d*d+g*b*b-2*b*d*f-a*c*g))/...
             ((b*b-a*c)*(+sqrt((a-c)^2+4*b*b)-(a+c))));
    
    bprime = sqrt((2*(a*f*f+c*d*d+g*b*b-2*b*d*f-a*c*g))/...
             ((b*b-a*c)*(-sqrt((a-c)^2+4*b*b)-(a+c))));
         
    % Angle
    if a < c
        theta = acot((a-c)/(2*b))/2;
    else
        theta = pi/2 + acot((a-c)/(2*b))/2;
    end
    
    %% We construct a matrix and a vector to correct the input data
    % The goal is to use:
    % [xin;yin] = A[xout;yout] + B
    
    % The rotation matrix to align the axes with the xy plane
    Brot = [cos(theta), sin(theta); -sin(theta), cos(theta)];
    % The stretch matrix to go back to a unit circle
    Bstr = [1/aprime,0;0,1/bprime];
    % The matrix A is the product of the two matrices above
    A = Bstr*Brot;
    % The recentering vector
    B = A*[-x0; -y0];
    
    %% We correct the input data
    arrayIn = [Xin, Yin]';
    arrayOut = A*arrayIn+repmat(B,[1,size(arrayIn,2)]);
    
    %% Deal with different output formats
    if nargout == 1
        varargout{1} = arrayOut(1,:)'+1j*arrayOut(2,:)';
    elseif nargout == 2
        varargout{1} = arrayOut(1,:)';
        varargout{2} = arrayOut(2,:)';
    elseif nargout == 3
        varargout{1} = arrayOut(1,:)'+1j*arrayOut(2,:)';
        varargout{2} = A;
        varargout{3} = B;
    elseif nargout == 4
        varargout{1} = arrayOut(1,:)';
        varargout{2} = arrayOut(2,:)';
        varargout{3} = A;
        varargout{4} = B;
    else
        error('Wrong number of output arguments');
    end
    
end

