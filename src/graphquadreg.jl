import LowRankModels: prox, prox!, evaluate
using LightGraphs
export MatrixRegularizer, GraphQuadReg, matrix, prox, prox!, evaluate

abstract MatrixRegularizer <: LowRankModels.Regularizer

type GraphQuadReg <: MatrixRegularizer
  QL::AbstractMatrix{Float64}
  scale::Float64
  idxgraph::IndexGraph
end

#Retrieve the matrix component of the regularizer for use in initialization
matrix(g::GraphQuadReg) = g.QL

## Pass in a graph and a quadratic regularization amount
function GraphQuadReg(g::LightGraphs.Graph, scale::Float64=1., quadamt::Float64=1.)
  L = laplacian_matrix(g)
  QL = L + quadamt*I
  GraphQuadReg(QL, scale, IndexGraph(g))
end

function GraphQuadReg(IG::IndexGraph, scale::Float64=1., quadamt::Float64=1.)
  QL = laplacian_matrix(IG.graph) + quadamt*I
  GraphQuadReg(QL, scale, IG)
end

function prox(g::GraphQuadReg, Y::AbstractMatrix{Float64}, α::Number;
              updateY::Bool=true)
  #Y*(2α*g.scale*g.QL + eye(g.QL))⁻¹
  #g.QL is guaranteed to be sparse and symmetric positive definite
  #Factorize (2α*g.scale*g.QL + I)
  QL = Symmetric((2α*g.scale)*g.QL)
  if updateY
    #invQLpI = cholfact(QL, shift=1.) \ eye(QL)
    #Y*invQLpI
    A_ldiv_Bt(cholfact(QL, shift=1.), Y)'
  else
    #Transpose the operation to work with regularizer on X
    A_ldiv_B(cholfact(QL, shift=1.), Y)
  end
end

function prox!(g::GraphQuadReg, Y::AbstractMatrix{Float64}, α::Number;
                updateY::Bool=true)
  #Y*(2α*g.scale*g.QL + eye(g.QL))⁻¹
  #g.QL is guaranteed to be sparse and symmetric positive definite
  #Factorize (2α*g.scale*g.QL + I)
  QL = Symmetric((2α*g.scale)*g.QL)
  if updateY
    #invQLpI = cholfact(QL, shift=1.) \ eye(QL)
    #Y*invQLpI
    transpose!(Y, A_ldiv_Bt(cholfact(QL, shift=1.), Y))
  else
    #Update X inplace
    copy!(Y, cholfact(QL, shift=1.) \ Y)
  end
end

function evaluate(g::GraphQuadReg, Y::AbstractMatrix{Float64}; updateY::Bool=true)
  if updateY
    g.scale*sum((Y'*Y) .* g.QL)
  else
    #Flip the evaluation if evaluating on X
    g.scale*sum((Y*Y') .* g.QL)
  end
end
